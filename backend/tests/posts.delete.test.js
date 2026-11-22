const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { signAppToken } = require('../middleware/auth.middleware');

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

const bearer = (sipUsername) =>
  `Bearer ${signAppToken({ _id: new mongoose.Types.ObjectId(), sipUsername })}`;

afterEach(async () => {
  await Post.deleteMany({});
});

describe('DELETE /api/posts/:id', () => {
  test('soft-deletes when the signed-in user is the author, and it disappears from the feed', async () => {
    const post = await Post.create({
      type: 'text', caption: 'mine', authorUserId: 'user1', authorName: 'Alice',
    });

    const res = await request(app)
      .delete(`/api/posts/${post._id}`)
      .set('Authorization', bearer('user1'));
    expect(res.status).toBe(200);

    const feed = await request(app).get('/api/posts');
    expect(feed.body.posts).toHaveLength(0);

    const stillInDb = await Post.findById(post._id);
    expect(stillInDb.isDeleted).toBe(true);
  });

  test('returns 403 when the signed-in user is not the author', async () => {
    const post = await Post.create({
      type: 'text', caption: 'not yours', authorUserId: 'user1', authorName: 'Alice',
    });

    const res = await request(app)
      .delete(`/api/posts/${post._id}`)
      .set('Authorization', bearer('user2'));
    expect(res.status).toBe(403);
  });

  test('returns 404 for a nonexistent post', async () => {
    const fakeId = new mongoose.Types.ObjectId();
    const res = await request(app)
      .delete(`/api/posts/${fakeId}`)
      .set('Authorization', bearer('user1'));
    expect(res.status).toBe(404);
  });

  test('returns 401 when the caller is not signed in', async () => {
    const post = await Post.create({
      type: 'text', caption: 'mine', authorUserId: 'user1', authorName: 'Alice',
    });

    const res = await request(app).delete(`/api/posts/${post._id}`).send({ authorUserId: 'user1' });
    expect(res.status).toBe(401);

    const stillThere = await Post.findById(post._id);
    expect(stillThere.isDeleted).toBe(false);
  });

  test('returns 404 (not 500) for a malformed post id', async () => {
    const res = await request(app).delete('/api/posts/not-a-real-id').set('Authorization', bearer('user1'));
    expect(res.status).toBe(404);
  });
});
