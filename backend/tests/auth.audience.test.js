const request = require('supertest');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;
let app;
let mw;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  mw = require('../middleware/auth.middleware');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

const adminToken = (role) =>
  mw.signAdminToken({ _id: new mongoose.Types.ObjectId(), role, username: 'admin1' });
const appToken = () =>
  mw.signAppToken({ _id: new mongoose.Types.ObjectId(), sipUsername: '263770000000' });

describe('token audiences', () => {
  test('admin token can create a product', async () => {
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken('staff')}`)
      .send({});
    expect(res.status).not.toBe(401);
  });

  test('app token is rejected on admin routes', async () => {
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${appToken()}`)
      .send({});
    expect(res.status).toBe(401);
  });

  test('legacy token without aud is rejected', async () => {
    const legacy = jwt.sign({ id: 'x', role: 'super_admin' }, process.env.JWT_SECRET);
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${legacy}`)
      .send({});
    expect(res.status).toBe(401);
  });

  test('verifyAppToken accepts app tokens only', () => {
    const id = new mongoose.Types.ObjectId();
    const t = mw.signAppToken({ _id: id, sipUsername: '263770000000' });
    expect(mw.verifyAppToken(t)).toEqual({ id: String(id), username: '263770000000' });
    expect(mw.verifyAppToken(adminToken('staff'))).toBeNull();
    expect(mw.verifyAppToken('garbage')).toBeNull();
    expect(mw.verifyAppToken(undefined)).toBeNull();
  });
});

describe('shop admin routes', () => {
  const shopWrites = [
    ['post', '/api/products'],
    ['post', '/api/categories'],
    ['patch', `/api/orders/${new mongoose.Types.ObjectId()}/status`],
  ];

  test.each(shopWrites)('kyc_reviewer gets 403 on %s %s', async (method, url) => {
    const res = await request(app)
      [method](url)
      .set('Authorization', `Bearer ${adminToken('kyc_reviewer')}`)
      .send({});
    expect(res.status).toBe(403);
  });

  test.each(shopWrites)('staff is still allowed on %s %s', async (method, url) => {
    const res = await request(app)
      [method](url)
      .set('Authorization', `Bearer ${adminToken('staff')}`)
      .send({});
    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });
});

describe('POST /api/auth/register', () => {
  test('public staff registration is closed', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ username: 'evil', password: 'pw123456' });
    expect(res.status).toBe(401);
  });

  test('super_admin can create staff', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('Authorization', `Bearer ${adminToken('super_admin')}`)
      .send({ username: 'newstaff', password: 'pw123456' });
    expect(res.status).toBe(201);
  });

  test('staff cannot create staff', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('Authorization', `Bearer ${adminToken('staff')}`)
      .send({ username: 'another', password: 'pw123456' });
    expect(res.status).toBe(403);
  });
});
