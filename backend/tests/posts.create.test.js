const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const path = require('path');

let mongoServer;
let app;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await mongoose.connection.collection('posts').deleteMany({});
});

describe('POST /api/posts', () => {
  test('creates a text post with no media file', async () => {
    const res = await request(app)
      .post('/api/posts')
      .field('type', 'text')
      .field('caption', 'Hello world')
      .field('authorUserId', 'user1')
      .field('authorName', 'Alice');

    expect(res.status).toBe(201);
    expect(res.body.type).toBe('text');
    expect(res.body.caption).toBe('Hello world');
    expect(res.body.mediaUrl).toBeFalsy();
  });

  test('creates a photo post with a media file', async () => {
    const tinyPngPath = path.join(__dirname, 'fixtures', 'tiny.png');

    const res = await request(app)
      .post('/api/posts')
      .field('type', 'photo')
      .field('authorUserId', 'user1')
      .field('authorName', 'Alice')
      .attach('media', tinyPngPath);

    expect(res.status).toBe(201);
    expect(res.body.type).toBe('photo');
    expect(res.body.mediaUrl).toMatch(/^\/uploads\//);
  });

  test('rejects a missing type', async () => {
    const res = await request(app)
      .post('/api/posts')
      .field('authorUserId', 'user1')
      .field('authorName', 'Alice');

    expect(res.status).toBe(400);
  });

  test('rejects a non-text post with no media file', async () => {
    const res = await request(app)
      .post('/api/posts')
      .field('type', 'photo')
      .field('authorUserId', 'user1')
      .field('authorName', 'Alice');

    expect(res.status).toBe(400);
  });

  test('rejects an unsupported mime type', async () => {
    const badFilePath = path.join(__dirname, 'fixtures', 'not-media.txt');

    const res = await request(app)
      .post('/api/posts')
      .field('type', 'photo')
      .field('authorUserId', 'user1')
      .field('authorName', 'Alice')
      .attach('media', badFilePath);

    expect(res.status).toBe(415);
  });

  test('rejects an audio file exceeding its type-specific size limit', async () => {
    // 16MB > audio's 15MB limit, but < the blanket 50MB multer ceiling —
    // exercises the manual per-type check, not multer's own LIMIT_FILE_SIZE.
    const oversizedBuffer = Buffer.alloc(16 * 1024 * 1024);

    const res = await request(app)
      .post('/api/posts')
      .field('type', 'audio')
      .field('authorUserId', 'user1')
      .field('authorName', 'Alice')
      .attach('media', oversizedBuffer, { filename: 'clip.mp3', contentType: 'audio/mpeg' });

    expect(res.status).toBe(400);
  });
});
