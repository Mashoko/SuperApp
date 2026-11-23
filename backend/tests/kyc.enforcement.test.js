const fs = require('fs');
const path = require('path');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createAppUserWithToken } = require('./helpers/app_user');

const TINY_PNG_PATH = path.join(__dirname, 'fixtures', 'tiny.png');
const TINY_PNG = fs.readFileSync(TINY_PNG_PATH);
const DAY = 86400000;
const ROLLOUT = new Date('2026-01-01T00:00:00Z');
const RESTRICTED_MESSAGE = 'Complete your KYC verification to keep using this feature.';

let mongoServer;
let app;
let AppUser;
let KycSettings;
let KycEvent;
let verifier;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  AppUser = require('../models/app_user.model');
  KycSettings = require('../kyc/models/kyc_settings.model');
  KycEvent = require('../kyc/models/kyc_event.model');
  verifier = require('../africom/verifier');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  await KycSettings.create({ rolloutAt: ROLLOUT });
});

afterEach(async () => {
  jest.restoreAllMocks();
  delete process.env.LEGACY_USERID_ROUTES;
  verifier.setVerifierForTests(null);
  await KycSettings.updateOne({}, { $set: { enforcementDays: 60 } });
  const names = ['appusers', 'kycevents', 'kycdrafts', 'kycdocuments', 'kycsubmissions', 'carts'];
  await Promise.all(names.map((n) => mongoose.connection.collection(n).deleteMany({})));
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

let phoneSeq = 0;
// Whole seconds so the deadline round-trips through JSON exactly.
const daysAgo = (days) => new Date(Math.floor((Date.now() - days * DAY) / 1000) * 1000);
const newUser = (opts = {}) => {
  phoneSeq += 1;
  return createAppUserWithToken({
    sipUsername: `+26377300${String(phoneSeq).padStart(4, '0')}`,
    ...opts,
  });
};
const pastDeadlineUser = (opts = {}) => newUser({ createdAt: daysAgo(70), ...opts });
const auth = (token) => ({ Authorization: `Bearer ${token}` });

const restrictedBody = (createdAt, underlyingStatus = 'NOT_STARTED') => ({
  code: 'KYC_RESTRICTED',
  message: RESTRICTED_MESSAGE,
  status: 'RESTRICTED',
  underlyingStatus,
  deadline: new Date(createdAt.getTime() + 60 * DAY).toISOString(),
});

const completeData = () => ({
  personal: {
    firstName: 'Tendai',
    lastName: 'Moyo',
    dateOfBirth: '1990-05-14',
    gender: 'female',
    nationality: 'Zimbabwean',
  },
  address: { line1: '12 Samora Machel Ave', city: 'Harare', country: 'Zimbabwe' },
  identification: { idType: 'national_id', idNumber: '63-1234567-X-42' },
});

const saveDraft = (token, data) =>
  request(app).put('/api/kyc/draft').set(auth(token)).send({ data });
const uploadDoc = (token, kind) =>
  request(app)
    .post('/api/kyc/documents')
    .set(auth(token))
    .field('kind', kind)
    .attach('file', TINY_PNG, { filename: 'id.png', contentType: 'image/png' });
const submitKyc = async (token) => {
  expect((await saveDraft(token, completeData())).status).toBe(200);
  expect((await uploadDoc(token, 'id_front')).status).toBe(201);
  expect((await uploadDoc(token, 'id_back')).status).toBe(201);
  return request(app).post('/api/kyc/submit').set(auth(token));
};

const fakeId = () => String(new mongoose.Types.ObjectId());

const PROTECTED = [
  ['GET', '/api/cart', null],
  ['POST', '/api/cart/add', () => ({ productId: fakeId(), quantity: 1 })],
  ['PUT', '/api/cart/update', () => ({ productId: fakeId(), quantity: 2 })],
  ['DELETE', '/api/cart/remove', () => ({ productId: fakeId() })],
  ['DELETE', '/api/cart/clear', null],
  ['POST', '/api/orders', () => ({ items: [{ product: { name: 'W' }, quantity: 1, total: 5 }], total: 5 })],
  ['GET', '/api/orders', null],
  ['GET', '/api/wishlist', null],
  ['POST', '/api/wishlist/add', () => ({ productId: fakeId() })],
  ['DELETE', `/api/wishlist/remove/${fakeId()}`, null],
  ['GET', '/api/shipping-addresses', null],
  ['POST', '/api/shipping-addresses', () => ({ fullName: 'T M', address: '12 Samora' })],
  ['DELETE', `/api/shipping-addresses/${fakeId()}`, null],
  ['POST', '/api/payments/africom/superapp-pay', () => ({ amount: 5, currency: 'USD', reference: 'r1' })],
  ['POST', '/api/posts', () => ({ type: 'text', caption: 'hi', authorName: 'Alice' })],
  ['POST', `/api/posts/${fakeId()}/like`, null],
  ['DELETE', `/api/posts/${fakeId()}`, null],
];

const send = (method, url, token, body) => {
  let r = request(app)[method.toLowerCase()](url);
  if (token) r = r.set(auth(token));
  return body ? r.send(body) : r;
};

describe('requireKycAccess', () => {
  test('user on day 10 can use the cart', async () => {
    const { token } = await newUser({ createdAt: daysAgo(10) });
    const res = await request(app).get('/api/cart').set(auth(token));
    expect(res.status).toBe(200);
  });

  describe('user past the deadline gets 403 KYC_RESTRICTED on cart, orders, wishlist, shipping addresses, payments, posts', () => {
    test.each(PROTECTED)('%s %s', async (method, url, body) => {
      const { appUser, token } = await pastDeadlineUser();
      const res = await send(method, url, token, body && body());
      expect(res.status).toBe(403);
      expect(res.body).toEqual(restrictedBody(appUser.createdAt));
    });
  });

  test('restricted user can still GET /api/kyc/me, save a draft, upload, submit, read notifications, browse products and FAQs, and refresh their session', async () => {
    const { appUser, token } = await pastDeadlineUser();
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(403);

    const me = await request(app).get('/api/kyc/me').set(auth(token));
    expect(me.status).toBe(200);
    expect(me.body.status).toBe('RESTRICTED');

    const products = await request(app).get('/api/products').set(auth(token));
    expect(products.status).toBe(200);
    const recommended = await request(app).get('/api/products?sort=recommended').set(auth(token));
    expect(recommended.status).toBe(200);
    expect((await request(app).get('/api/faqs')).status).toBe(200);

    verifier.setVerifierForTests(async () => ({ ok: true, username: appUser.sipUsername }));
    const session = await request(app)
      .post('/api/app-auth/session')
      .send({ username: appUser.sipUsername, password: 'pw' });
    expect(session.status).toBe(200);
    expect(session.body.user.id).toBe(String(appUser._id));

    // Notifications are delivered by the client and the reminder job; there is no
    // server notifications route to gate. Draft, upload and submit stay open:
    const submit = await submitKyc(token);
    expect(submit.status).toBe(201);
  });

  test('restricted user who submits regains cart access immediately', async () => {
    const { appUser, token } = await pastDeadlineUser();
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(403);
    expect((await AppUser.findById(appUser._id)).kyc.restrictedAt).toBeInstanceOf(Date);

    expect((await submitKyc(token)).status).toBe(201);

    const res = await request(app).get('/api/cart').set(auth(token));
    expect(res.status).toBe(200);
    expect((await AppUser.findById(appUser._id)).kyc.restrictedAt).toBeUndefined();
    expect(await KycEvent.countDocuments({ appUserId: appUser._id, type: 'UNRESTRICTED' })).toBe(1);
  });

  test('cached restriction that no longer applies is cleared with an UNRESTRICTED event', async () => {
    const { appUser, token } = await newUser({
      createdAt: daysAgo(10),
      kyc: { status: 'IN_PROGRESS', restrictedAt: daysAgo(1) },
    });
    const res = await request(app).get('/api/cart').set(auth(token));
    expect(res.status).toBe(200);
    expect((await AppUser.findById(appUser._id)).kyc.restrictedAt).toBeUndefined();
    const events = await KycEvent.find({ appUserId: appUser._id, type: 'UNRESTRICTED' });
    expect(events).toHaveLength(1);

    await request(app).get('/api/cart').set(auth(token));
    expect(await KycEvent.countDocuments({ appUserId: appUser._id, type: 'UNRESTRICTED' })).toBe(1);
  });

  test('approved user past the deadline is not restricted', async () => {
    const { token } = await pastDeadlineUser({ kyc: { status: 'APPROVED' } });
    const res = await request(app).get('/api/cart').set(auth(token));
    expect(res.status).toBe(200);
  });

  test('lowering enforcementDays restricts on the next request', async () => {
    const createdAt = daysAgo(30);
    const { token } = await newUser({ createdAt });
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(200);

    await KycSettings.updateOne({}, { $set: { enforcementDays: 20 } });
    const res = await request(app).get('/api/cart').set(auth(token));
    expect(res.status).toBe(403);
    expect(res.body.deadline).toBe(new Date(createdAt.getTime() + 20 * DAY).toISOString());
  });

  test('before launch a user 61 days old is not restricted', async () => {
    await KycSettings.updateOne({}, { $set: { rolloutAt: null } });
    try {
      const { appUser, token } = await newUser({ createdAt: daysAgo(61) });
      expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(200);
      const me = await request(app).get('/api/kyc/me').set(auth(token));
      expect(me.body).toMatchObject({ status: 'NOT_STARTED', launched: false, deadline: null });
      const stored = await AppUser.findById(appUser._id);
      expect(stored.kyc.restrictedAt).toBeUndefined();
      expect(await KycEvent.countDocuments({ type: 'RESTRICTED' })).toBe(0);
    } finally {
      await KycSettings.updateOne({}, { $set: { rolloutAt: ROLLOUT } });
    }
  });

  test('a missing encryption key after launch lifts restriction on protected routes', async () => {
    const { token } = await pastDeadlineUser();
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(403);
    const saved = process.env.KYC_ENCRYPTION_KEY;
    delete process.env.KYC_ENCRYPTION_KEY;
    try {
      for (const [method, url, body] of PROTECTED.slice(0, 3)) {
        const res = await send(method, url, token, body && body());
        expect(res.status).not.toBe(403);
      }
      expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(200);
      // A token whose AppUser is gone is still 401, key or not.
      const gone = await newUser();
      await AppUser.deleteOne({ _id: gone.appUser._id });
      expect((await request(app).get('/api/cart').set(auth(gone.token))).status).toBe(401);
    } finally {
      process.env.KYC_ENCRYPTION_KEY = saved;
    }
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(403);
  });

  test('legacy request (no token) is not enforced', async () => {
    process.env.LEGACY_USERID_ROUTES = 'true';
    const { appUser } = await pastDeadlineUser();
    const res = await request(app).get('/api/cart').query({ userId: appUser.sipUsername });
    expect(res.status).toBe(200);
  });

  test('valid token whose AppUser row is missing is 401', async () => {
    const { appUser, token } = await newUser({ createdAt: daysAgo(10) });
    await AppUser.deleteOne({ _id: appUser._id });
    const res = await request(app).get('/api/cart').set(auth(token));
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ message: 'Sign in required.' });
  });

  test('RESTRICTED event written once even after several blocked requests', async () => {
    const { appUser, token } = await pastDeadlineUser();
    await Promise.all([1, 2, 3].map(() => request(app).get('/api/cart').set(auth(token))));
    for (let i = 0; i < 3; i += 1) {
      expect((await request(app).get('/api/orders').set(auth(token))).status).toBe(403);
    }
    const events = await KycEvent.find({ appUserId: appUser._id, type: 'RESTRICTED' });
    expect(events).toHaveLength(1);
    expect(events[0].idempotencyKey).toBe(`${appUser._id}:restricted:0`);
    expect((await AppUser.findById(appUser._id)).kyc.restrictedAt).toBeInstanceOf(Date);
  });

  test('a failed RESTRICTED event insert still returns 403, leaves restrictedAt unset, and is retried', async () => {
    const { appUser, token } = await pastDeadlineUser();
    const createSpy = jest
      .spyOn(KycEvent, 'create')
      .mockRejectedValueOnce(Object.assign(new Error('x'), { name: 'MongoError' }));
    jest.spyOn(console, 'error').mockImplementation(() => {});

    const res = await request(app).get('/api/cart').set(auth(token));
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('KYC_RESTRICTED');
    expect((await AppUser.findById(appUser._id)).kyc.restrictedAt).toBeUndefined();
    expect(await KycEvent.countDocuments({ appUserId: appUser._id, type: 'RESTRICTED' })).toBe(0);

    createSpy.mockRestore();
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(403);
    const events = await KycEvent.find({ appUserId: appUser._id, type: 'RESTRICTED' });
    expect(events).toHaveLength(1);
    expect(events[0].idempotencyKey).toBe(`${appUser._id}:restricted:0`);
    expect((await AppUser.findById(appUser._id)).kyc.restrictedAt).toBeInstanceOf(Date);
  });

  test('a restrictedAt cache failure still returns 403, not 500', async () => {
    const { appUser, token } = await pastDeadlineUser();
    jest
      .spyOn(AppUser, 'findOneAndUpdate')
      .mockRejectedValueOnce(Object.assign(new Error('x'), { name: 'MongoError' }));
    jest.spyOn(console, 'error').mockImplementation(() => {});
    const res = await request(app).get('/api/cart').set(auth(token));
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('KYC_RESTRICTED');
    expect(await KycEvent.countDocuments({ appUserId: appUser._id, type: 'RESTRICTED' })).toBe(1);
  });

  test('post upload rejected with 403 leaves no file in uploads/', async () => {
    const { token } = await pastDeadlineUser();
    const uploads = path.join(process.cwd(), 'uploads');
    const before = new Set(fs.readdirSync(uploads));

    const res = await request(app)
      .post('/api/posts')
      .set(auth(token))
      .field('type', 'photo')
      .field('authorName', 'Alice')
      .attach('media', TINY_PNG_PATH);
    expect(res.status).toBe(403);

    const added = fs.readdirSync(uploads).filter((f) => !before.has(f));
    expect(added).toEqual([]);
  });
});
