const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createAppUserWithToken } = require('./helpers/app_user');

const DAY = 86400000;
const ROLLOUT = new Date('2026-01-01T00:00:00Z');

let mongoServer;
let app;
let AppUser;
let KycSettings;
let Notification;
let notifications;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  AppUser = require('../models/app_user.model');
  KycSettings = require('../kyc/models/kyc_settings.model');
  Notification = require('../kyc/models/notification.model');
  notifications = require('../kyc/notifications');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  await KycSettings.create({ rolloutAt: ROLLOUT });
});

afterEach(async () => {
  jest.restoreAllMocks();
  delete process.env.LEGACY_USERID_ROUTES;
  await Promise.all([AppUser.deleteMany({}), Notification.deleteMany({})]);
  await mongoose.connection.collection('kycevents').deleteMany({});
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

let phoneSeq = 0;
const newUser = (opts = {}) => {
  phoneSeq += 1;
  return createAppUserWithToken({
    sipUsername: `+26377500${String(phoneSeq).padStart(4, '0')}`,
    ...opts,
  });
};
const auth = (token) => ({ Authorization: `Bearer ${token}` });

// Inserts notifications with increasing createdAt so newest-first order is deterministic.
const seed = async (appUserId, count, { readCount = 0 } = {}) => {
  const base = Date.UTC(2026, 10, 1);
  const docs = [];
  for (let i = 0; i < count; i += 1) {
    docs.push({
      appUserId,
      kind: 'REMINDER',
      title: `Title ${i}`,
      body: `Body ${i}`,
      createdAt: new Date(base + i * 60000),
      readAt: i < readCount ? new Date(base + i * 60000 + 1000) : null,
      deliveredVia: ['in_app'],
    });
  }
  await Notification.collection.insertMany(docs);
};

describe('notify', () => {
  test('stores the rendered template with deliveredVia in_app', async () => {
    const { appUser } = await newUser();
    const n = await notifications.notify(appUser._id, 'REJECTED', {
      reason: 'The ID photo is blurry',
      deadline: new Date('2027-01-22T23:30:00Z'),
    });
    expect(n.kind).toBe('REJECTED');
    expect(n.title).toBe('KYC not approved');
    expect(n.body).toBe(
      'Reason: The ID photo is blurry. Please correct your details and submit again before 22 January 2027.'
    );
    expect(n.deliveredVia).toEqual(['in_app']);
    expect(await Notification.countDocuments({ appUserId: appUser._id })).toBe(1);
  });

  test('formats the deadline in UTC', () => {
    expect(notifications.formatDeadline(new Date('2027-01-22T00:00:00Z'))).toBe('22 January 2027');
    expect(notifications.formatDeadline(new Date('2027-03-15T23:59:59Z'))).toBe('15 March 2027');
  });

  test('every template renders without em dashes', () => {
    const vars = { deadline: new Date('2027-01-22T00:00:00Z'), reason: 'Blurry photo' };
    for (const kind of Object.keys(notifications.TEMPLATES)) {
      const { title, body } = notifications.render(kind, vars);
      expect(`${title} ${body}`).not.toMatch(/[—{}]/);
    }
  });

  test('rejects an unknown kind and a missing variable', async () => {
    const { appUser } = await newUser();
    await expect(notifications.notify(appUser._id, 'NOPE', {})).rejects.toThrow();
    await expect(notifications.notify(appUser._id, 'NUDGE_1', {})).rejects.toThrow();
    expect(await Notification.countDocuments({})).toBe(0);
  });
});

describe('GET /api/notifications', () => {
  test('lists 20 per page, newest first, with the unread count', async () => {
    const { appUser, token } = await newUser();
    const other = await newUser();
    await seed(appUser._id, 25, { readCount: 3 });
    await seed(other.appUser._id, 4);

    const page1 = await request(app).get('/api/notifications').set(auth(token));
    expect(page1.status).toBe(200);
    expect(page1.body.page).toBe(1);
    expect(page1.body.totalPages).toBe(2);
    expect(page1.body.unread).toBe(22);
    expect(page1.body.items).toHaveLength(20);
    expect(page1.body.items[0].title).toBe('Title 24');
    expect(page1.body.items[19].title).toBe('Title 5');
    expect(Object.keys(page1.body.items[0]).sort()).toEqual(
      ['body', 'createdAt', 'id', 'kind', 'readAt', 'title'].sort()
    );

    const page2 = await request(app).get('/api/notifications?page=2').set(auth(token));
    expect(page2.body.page).toBe(2);
    expect(page2.body.items.map((i) => i.title)).toEqual([
      'Title 4',
      'Title 3',
      'Title 2',
      'Title 1',
      'Title 0',
    ]);
    expect(page2.body.items[4].readAt).toEqual(expect.any(String));
  });

  test('an empty inbox and a bad page number are handled', async () => {
    const { token } = await newUser();
    const res = await request(app).get('/api/notifications?page=abc').set(auth(token));
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ items: [], unread: 0, page: 1, totalPages: 0 });
  });

  test('no token is 401', async () => {
    const res = await request(app).get('/api/notifications');
    expect(res.status).toBe(401);
  });

  test('legacy request (no token, LEGACY on) is 401', async () => {
    process.env.LEGACY_USERID_ROUTES = 'true';
    const { appUser } = await newUser();
    const res = await request(app).get(`/api/notifications?userId=${encodeURIComponent(appUser.sipUsername)}`);
    expect(res.status).toBe(401);
  });

  test('valid token whose AppUser row is missing is 401', async () => {
    const { appUser, token } = await newUser();
    await AppUser.deleteOne({ _id: appUser._id });
    const res = await request(app).get('/api/notifications').set(auth(token));
    expect(res.status).toBe(401);
  });

  test('restricted user can read notifications', async () => {
    const { appUser, token } = await newUser({ createdAt: new Date(Date.now() - 70 * DAY) });
    await seed(appUser._id, 1);
    const blocked = await request(app).get('/api/cart').set(auth(token));
    expect(blocked.status).toBe(403);
    expect(blocked.body.code).toBe('KYC_RESTRICTED');

    const res = await request(app).get('/api/notifications').set(auth(token));
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(1);
    const id = res.body.items[0].id;
    const read = await request(app).post(`/api/notifications/${id}/read`).set(auth(token));
    expect(read.status).toBe(200);
  });
});

describe('POST /api/notifications/:id/read', () => {
  test('marks the notification read and lowers the unread count', async () => {
    const { appUser, token } = await newUser();
    await seed(appUser._id, 2);
    const list = await request(app).get('/api/notifications').set(auth(token));
    const id = list.body.items[0].id;

    const res = await request(app).post(`/api/notifications/${id}/read`).set(auth(token));
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(id);
    expect(res.body.readAt).toEqual(expect.any(String));

    // Marking again keeps the first readAt.
    const again = await request(app).post(`/api/notifications/${id}/read`).set(auth(token));
    expect(again.status).toBe(200);
    expect(again.body.readAt).toBe(res.body.readAt);

    const after = await request(app).get('/api/notifications').set(auth(token));
    expect(after.body.unread).toBe(1);
  });

  test("user B cannot mark user A's notification", async () => {
    const a = await newUser();
    const b = await newUser();
    await seed(a.appUser._id, 1);
    const [note] = await Notification.find({ appUserId: a.appUser._id });

    const res = await request(app).post(`/api/notifications/${note._id}/read`).set(auth(b.token));
    expect(res.status).toBe(404);
    expect((await Notification.findById(note._id)).readAt).toBeNull();
  });

  test('a malformed or unknown id is 404', async () => {
    const { token } = await newUser();
    const bad = await request(app).post('/api/notifications/not-an-id/read').set(auth(token));
    expect(bad.status).toBe(404);
    const unknown = await request(app)
      .post(`/api/notifications/${new mongoose.Types.ObjectId()}/read`)
      .set(auth(token));
    expect(unknown.status).toBe(404);
  });

  test('no token is 401', async () => {
    const res = await request(app).post(`/api/notifications/${new mongoose.Types.ObjectId()}/read`);
    expect(res.status).toBe(401);
  });
});
