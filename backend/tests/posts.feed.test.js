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

describe('GET /api/posts', () => {
  test('paginates correctly across two pages', async () => {
    for (let i = 0; i < 15; i++) {
      await Post.create({
        type: 'text',
        caption: `Post ${i}`,
        authorUserId: 'user1',
        authorName: 'Alice',
      });
    }

    const page1 = await request(app).get('/api/posts?page=1&limit=10');
    expect(page1.status).toBe(200);
    expect(page1.body.posts).toHaveLength(10);
    expect(page1.body.totalPosts).toBe(15);
    expect(page1.body.totalPages).toBe(2);
    expect(page1.body.currentPage).toBe(1);

    const page2 = await request(app).get('/api/posts?page=2&limit=10');
    expect(page2.body.posts).toHaveLength(5);
    expect(page2.body.currentPage).toBe(2);
  });

  test('returns newest posts first', async () => {
    const older = await Post.create({
      type: 'text', caption: 'older', authorUserId: 'user1', authorName: 'Alice',
    });
    await new Promise((resolve) => setTimeout(resolve, 10));
    const newer = await Post.create({
      type: 'text', caption: 'newer', authorUserId: 'user1', authorName: 'Alice',
    });

    const res = await request(app).get('/api/posts');
    expect(res.body.posts[0]._id).toBe(String(newer._id));
    expect(res.body.posts[1]._id).toBe(String(older._id));
  });

  test('excludes soft-deleted posts', async () => {
    await Post.create({
      type: 'text', caption: 'visible', authorUserId: 'user1', authorName: 'Alice',
    });
    await Post.create({
      type: 'text', caption: 'deleted', authorUserId: 'user1', authorName: 'Alice', isDeleted: true,
    });

    const res = await request(app).get('/api/posts');
    expect(res.body.posts).toHaveLength(1);
    expect(res.body.posts[0].caption).toBe('visible');
  });
});
