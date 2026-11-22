// Rate limits on POST /api/app-auth/session. The limiters are real (in-memory,
// fresh for this test file); tests use distinct usernames so they do not share budget.
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;
let app;
let verifier;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  verifier = require('../africom/verifier');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
});

beforeEach(() => {
  verifier.setVerifierForTests(async () => ({ ok: false, reason: 'invalid' }));
});

afterAll(async () => {
  verifier.setVerifierForTests(null);
  await mongoose.disconnect();
  await mongoServer.stop();
});

const session = (username) =>
  request(app).post('/api/app-auth/session').send({ username, password: 'bad' });

const TOO_MANY = { message: 'Too many requests, please try again later.' };

test('per-account limit: 11th attempt for one username is 429, another username still passes', async () => {
  for (let i = 0; i < 10; i += 1) {
    const res = await session('263770000001');
    expect(res.status).toBe(401);
  }
  const blocked = await session('263770000001');
  expect(blocked.status).toBe(429);
  expect(blocked.body).toEqual(TOO_MANY);

  // Same account in another format shares the canonical key.
  const plus = await session('+263770000001');
  expect(plus.status).toBe(429);

  const other = await session('263770000002');
  expect(other.status).toBe(401);
});

test('app-session traffic does not consume the staff login budget', async () => {
  // More than authLimiter's 20, each on its own account.
  for (let i = 0; i < 25; i += 1) {
    const res = await session(`2637710000${String(i).padStart(2, '0')}`);
    expect(res.status).toBe(401);
  }
  const staff = await request(app)
    .post('/api/auth/login')
    .send({ username: 'nobody', password: 'wrong' });
  expect(staff.status).toBe(400);
  expect(staff.body).toEqual({ message: 'Invalid credentials' });
});
