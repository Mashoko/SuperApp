const request = require('supertest');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;
let app;
let Faq;
let authToken;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  Faq = require('../models/faq.model');
  authToken = jwt.sign({ id: 'test-admin' }, process.env.JWT_SECRET);
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await Faq.deleteMany({});
});

describe('GET /api/faqs', () => {
  test('returns all FAQ categories, no auth required', async () => {
    await Faq.create({ title: 'Payments', items: [{ question: 'Q1', answer: 'A1' }] });

    const res = await request(app).get('/api/faqs');

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].title).toBe('Payments');
    expect(res.body[0].items[0].question).toBe('Q1');
  });

  test('returns an empty array (not an error) when there are no FAQ categories', async () => {
    const res = await request(app).get('/api/faqs');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});

describe('POST /api/faqs', () => {
  test('rejects the request with no auth token', async () => {
    const res = await request(app)
      .post('/api/faqs')
      .send({ title: 'Wallet', items: [] });
    expect(res.status).toBe(401);
  });

  test('creates a new FAQ category with a valid token', async () => {
    const res = await request(app)
      .post('/api/faqs')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ title: 'Wallet', items: [{ question: 'Q', answer: 'A' }] });

    expect(res.status).toBe(201);
    expect(res.body.title).toBe('Wallet');
    const stored = await Faq.findOne({ title: 'Wallet' });
    expect(stored).not.toBeNull();
  });

  test('rejects a category with no title', async () => {
    const res = await request(app)
      .post('/api/faqs')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ items: [] });
    expect(res.status).toBe(400);
  });
});

describe('PUT /api/faqs/:id', () => {
  test("updates an existing category's items", async () => {
    const faq = await Faq.create({ title: 'General', items: [{ question: 'Old Q', answer: 'Old A' }] });

    const res = await request(app)
      .put(`/api/faqs/${faq._id}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ title: 'General', items: [{ question: 'New Q', answer: 'New A' }] });

    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0].question).toBe('New Q');
  });

  test('rejects an update with no auth token', async () => {
    const faq = await Faq.create({ title: 'General', items: [] });
    const res = await request(app)
      .put(`/api/faqs/${faq._id}`)
      .send({ title: 'General', items: [] });
    expect(res.status).toBe(401);
  });
});

describe('DELETE /api/faqs/:id', () => {
  test('deletes an existing category', async () => {
    const faq = await Faq.create({ title: 'Temp', items: [] });

    const res = await request(app)
      .delete(`/api/faqs/${faq._id}`)
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    const stored = await Faq.findById(faq._id);
    expect(stored).toBeNull();
  });

  test('rejects a delete with no auth token', async () => {
    const faq = await Faq.create({ title: 'Temp', items: [] });
    const res = await request(app).delete(`/api/faqs/${faq._id}`);
    expect(res.status).toBe(401);
  });
});
