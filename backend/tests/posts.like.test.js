const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;
let app;
let Post;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  Post = require('../models/post.model');
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await Post.deleteMany({});
});

describe('POST /api/posts/:id/like', () => {
  test('toggles like on, then off, then on again', async () => {
    const post = await Post.create({
      type: 'text', caption: 'hi', authorUserId: 'user1', authorName: 'Alice',
    });

    const first = await request(app).post(`/api/posts/${post._id}/like`).send({ userId: 'user2' });
    expect(first.body).toEqual({ liked: true, likeCount: 1 });

    const second = await request(app).post(`/api/posts/${post._id}/like`).send({ userId: 'user2' });
    expect(second.body).toEqual({ liked: false, likeCount: 0 });

    const third = await request(app).post(`/api/posts/${post._id}/like`).send({ userId: 'user2' });
    expect(third.body).toEqual({ liked: true, likeCount: 1 });
  });

  test('returns 400 when userId is missing', async () => {
    const post = await Post.create({
      type: 'text', caption: 'hi', authorUserId: 'user1', authorName: 'Alice',
    });

    const res = await request(app).post(`/api/posts/${post._id}/like`).send({});
    expect(res.status).toBe(400);
  });

  test('returns 404 for a nonexistent post', async () => {
    const fakeId = new mongoose.Types.ObjectId();
    const res = await request(app).post(`/api/posts/${fakeId}/like`).send({ userId: 'user2' });
    expect(res.status).toBe(404);
  });

  test('concurrent likes from different users are both recorded (no lost update)', async () => {
    const post = await Post.create({
      type: 'text', caption: 'hi', authorUserId: 'user1', authorName: 'Alice',
    });

    await Promise.all([
      request(app).post(`/api/posts/${post._id}/like`).send({ userId: 'userA' }),
      request(app).post(`/api/posts/${post._id}/like`).send({ userId: 'userB' }),
    ]);

    const fetched = await Post.findById(post._id);
    expect(fetched.likedBy.sort()).toEqual(['userA', 'userB']);
    expect(fetched.likedBy.length).toBe(2);
  });

  test('returns 404 (not 500) for a malformed post id', async () => {
    const res = await request(app).post('/api/posts/not-a-real-id/like').send({ userId: 'user2' });
    expect(res.status).toBe(404);
  });

  test('returns 404 for a soft-deleted post', async () => {
    const post = await Post.create({
      type: 'text', caption: 'gone', authorUserId: 'user1', authorName: 'Alice', isDeleted: true,
    });

    const res = await request(app).post(`/api/posts/${post._id}/like`).send({ userId: 'user2' });
    expect(res.status).toBe(404);
  });
});
