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

describe('DELETE /api/posts/:id', () => {
  test('soft-deletes when authorUserId matches, and it disappears from the feed', async () => {
    const post = await Post.create({
      type: 'text', caption: 'mine', authorUserId: 'user1', authorName: 'Alice',
    });

    const res = await request(app)
      .delete(`/api/posts/${post._id}`)
      .send({ authorUserId: 'user1' });
    expect(res.status).toBe(200);

    const feed = await request(app).get('/api/posts');
    expect(feed.body.posts).toHaveLength(0);

    const stillInDb = await Post.findById(post._id);
    expect(stillInDb.isDeleted).toBe(true);
  });

  test('returns 403 when authorUserId does not match', async () => {
    const post = await Post.create({
      type: 'text', caption: 'not yours', authorUserId: 'user1', authorName: 'Alice',
    });

    const res = await request(app)
      .delete(`/api/posts/${post._id}`)
      .send({ authorUserId: 'user2' });
    expect(res.status).toBe(403);
  });

  test('returns 404 for a nonexistent post', async () => {
    const fakeId = new mongoose.Types.ObjectId();
    const res = await request(app)
      .delete(`/api/posts/${fakeId}`)
      .send({ authorUserId: 'user1' });
    expect(res.status).toBe(404);
  });

  test('returns 400 when authorUserId is missing', async () => {
    const post = await Post.create({
      type: 'text', caption: 'mine', authorUserId: 'user1', authorName: 'Alice',
    });

    const res = await request(app).delete(`/api/posts/${post._id}`).send({});
    expect(res.status).toBe(400);
  });
});
