const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const Post = require('../models/post.model');

let mongoServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await Post.deleteMany({});
});

describe('Post model', () => {
  test('creates a valid text post with correct defaults', async () => {
    const post = await Post.create({
      type: 'text',
      caption: 'Hello world',
      authorUserId: 'user1',
      authorName: 'Alice',
    });
    expect(post.type).toBe('text');
    expect(post.caption).toBe('Hello world');
    expect(post.likedBy).toEqual([]);
    expect(post.commentCount).toBe(0);
    expect(post.isDeleted).toBe(false);
    expect(post.createdAt).toBeInstanceOf(Date);
  });

  test('rejects an invalid type', async () => {
    await expect(Post.create({
      type: 'not-a-real-type',
      authorUserId: 'user1',
      authorName: 'Alice',
    })).rejects.toThrow();
  });

  test('requires authorUserId and authorName', async () => {
    await expect(Post.create({ type: 'text' })).rejects.toThrow();
  });
});
