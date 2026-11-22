const request = require('supertest');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;
let app;
let mw;
let verifier;
let AppUser;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  mw = require('../middleware/auth.middleware');
  verifier = require('../africom/verifier');
  AppUser = require('../models/app_user.model');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
});

afterEach(async () => {
  verifier.setVerifierForTests(null);
  await AppUser.deleteMany({});
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

const stubOk = (username) =>
  verifier.setVerifierForTests(async () => ({ ok: true, username }));
const session = (body) => request(app).post('/api/app-auth/session').send(body);

describe('POST /api/app-auth/session', () => {
  test('creates AppUser and returns app token on valid credentials', async () => {
    stubOk('263771234567');
    const res = await session({ username: '263771234567', password: 'pw', displayName: ' Tendai ' });
    expect(res.status).toBe(200);
    const decoded = jwt.verify(res.body.token, process.env.JWT_SECRET);
    expect(decoded.aud).toBe('app');
    expect(decoded.username).toBe('+263771234567');
    expect(res.body.user).toEqual({
      id: String(decoded.sub),
      username: '+263771234567',
      displayName: 'Tendai',
    });
    expect(await AppUser.countDocuments()).toBe(1);
  });

  test('second session reuses the same AppUser', async () => {
    stubOk('263771234567');
    const a = await session({ username: '263771234567', password: 'pw', displayName: 'Tendai' });
    const b = await session({ username: '263771234567', password: 'pw' });
    expect(b.body.user.id).toBe(a.body.user.id);
    expect(b.body.user.displayName).toBe('Tendai');
    expect(await AppUser.countDocuments()).toBe(1);
  });

  test('logins with and without + map to one canonical AppUser', async () => {
    // Mimics the real verifier on an account Afri Com knows without '+':
    // it accepts the bare number and, for '+…', retries and returns the stripped form.
    verifier.setVerifierForTests(async (u) => ({ ok: true, username: u.replace(/^\+/, '') }));
    const a = await session({ username: '263771234567', password: 'pw' });
    const b = await session({ username: '+263771234567', password: 'pw' });
    expect(a.status).toBe(200);
    expect(b.status).toBe(200);
    expect(b.body.user.id).toBe(a.body.user.id);
    expect(a.body.user.username).toBe('+263771234567');
    expect(b.body.user.username).toBe('+263771234567');
    for (const res of [a, b]) {
      expect(jwt.verify(res.body.token, process.env.JWT_SECRET).username).toBe('+263771234567');
    }
    expect(await AppUser.countDocuments()).toBe(1);
    expect((await AppUser.findOne()).sipUsername).toBe('+263771234567');
  });

  test('verifier is called with the submitted form, not the canonical one', async () => {
    const spy = jest.fn(async (u) => ({ ok: true, username: u }));
    verifier.setVerifierForTests(spy);
    await session({ username: ' 263771234567 ', password: 'pw' });
    expect(spy.mock.calls[0].slice(0, 2)).toEqual(['263771234567', 'pw']);
  });

  test('invalid credentials return 401 with generic message', async () => {
    verifier.setVerifierForTests(async () => ({ ok: false, reason: 'invalid' }));
    const res = await session({ username: '263771234567', password: 'bad' });
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ message: 'Phone number or password is incorrect.' });
    expect(await AppUser.countDocuments()).toBe(0);
  });

  test('verifier unavailable returns 503', async () => {
    verifier.setVerifierForTests(async () => ({ ok: false, reason: 'unavailable' }));
    const res = await session({ username: '263771234567', password: 'pw' });
    expect(res.status).toBe(503);
    expect(res.body).toEqual({ message: 'Verification service unavailable. Try again shortly.' });
  });

  test('missing or malformed fields return 400 without calling verifier', async () => {
    const spy = jest.fn();
    verifier.setVerifierForTests(spy);
    for (const body of [
      {},
      { username: '263771234567' },
      { password: 'pw' },
      { username: '   ', password: 'pw' },
      { username: '+', password: 'pw' },
      { username: { $ne: '' }, password: 'pw' },
      { username: '263771234567', password: { $ne: '' } },
      { username: '263771234567', password: 'pw', displayName: 5 },
    ]) {
      const res = await session(body);
      expect(res.status).toBe(400);
      expect(res.body).toEqual({ message: 'Phone number and password are required.' });
    }
    expect(spy).not.toHaveBeenCalled();
  });
});

describe('GET /api/app-auth/me', () => {
  test('returns user with app token, 401 with admin token', async () => {
    stubOk('263771234567');
    const s = await session({ username: '263771234567', password: 'pw', displayName: 'Tendai' });
    const ok = await request(app)
      .get('/api/app-auth/me')
      .set('Authorization', `Bearer ${s.body.token}`);
    expect(ok.status).toBe(200);
    expect(ok.body).toEqual(s.body.user);

    const admin = mw.signAdminToken({
      _id: new mongoose.Types.ObjectId(), role: 'staff', username: 'admin1',
    });
    const bad = await request(app)
      .get('/api/app-auth/me')
      .set('Authorization', `Bearer ${admin}`);
    expect(bad.status).toBe(401);
  });
});
