# Posts Backend API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Post` model and REST API (create, paginated feed, like-toggle, soft-delete) to the existing Node/Express/Mongoose backend, supporting 4 post types (photo, video, text, audio), with real Jest+Supertest test coverage backed by `mongodb-memory-server`.

**Architecture:** One new Mongoose model (`backend/models/post.model.js`) plus 4 new flat routes added directly to `backend/index.js`, following the exact conventions already used by `/api/products` etc. (no router/controller split, no `auth` middleware — these routes trust a client-supplied `userId`/`authorUserId`, matching the existing cart/wishlist/orders convention). A second `multer` instance extends media upload to video/audio alongside the existing image-only one. `index.js` gets a small testability refactor (export the Express `app`, guard `app.listen` behind `require.main === module`) so Supertest can exercise it without starting a real server or touching the real database.

**Tech Stack:** Node.js, Express 5, Mongoose 8, Multer 2, Jest, Supertest, `mongodb-memory-server`.

## Global Constraints

- No `auth` (admin JWT) middleware on any new route — all trust a client-supplied `userId`/`authorUserId` string, matching the existing unauthenticated convention used by `/api/cart/*`, `/api/wishlist/*`, `/api/orders`.
- Pagination response shape matches `/api/products` exactly: `{ items, totalPages, currentPage, totalItems }`-style keys (here: `posts`, `totalPages`, `currentPage`, `totalPosts`).
- 4 post types only: `photo`, `video`, `text`, `audio`. Text posts have no media file; the other 3 require one.
- Media size limits by mime type: images 5MB (unchanged from the existing `/api/upload` limit), video (`video/mp4`, `video/quicktime`) 50MB, audio (`audio/mpeg`, `audio/mp4`, `audio/wav`) 15MB.
- Real per-user like/unlike via a `likedBy: [String]` array — no separate fire-and-forget counter.
- Comment count is stored (`commentCount`, default 0) but nothing increments it this round — no comment-creation endpoint.
- Soft delete only (`isDeleted: true`), matching `product.model.js`'s existing convention — never actually remove a document.
- Existing `/api/upload` route, its `multer` instance, and its 5MB image-only limits are untouched.
- Tests use `mongodb-memory-server` — never connect to the real deployed MongoDB, never start a real `app.listen()`.

---

### Task 1: Test tooling + `Post` model

**Files:**
- Modify: `backend/package.json` (add `jest`, `supertest`, `mongodb-memory-server` devDependencies via `npm install`; change the `"test"` script)
- Create: `backend/models/post.model.js`
- Test: `backend/tests/post.model.test.js`

**Interfaces:**
- Produces: `Post` — a Mongoose model with fields `type` (enum: `photo`/`video`/`text`/`audio`, required), `caption` (String, optional), `mediaUrl` (String, optional), `audioTitle` (String, optional), `durationSeconds` (Number, optional), `authorUserId` (String, required), `authorName` (String, required), `likedBy` (`[String]`, default `[]`), `commentCount` (Number, default `0`), `isDeleted` (Boolean, default `false`), plus Mongoose's `timestamps` (`createdAt`, `updatedAt`). Consumed by Tasks 2-5.

- [ ] **Step 1: Install test tooling**

Run: `cd backend && npm install --save-dev jest supertest mongodb-memory-server`
Expected: `package.json`'s `devDependencies` gains `jest`, `supertest`, `mongodb-memory-server` (exact versions chosen by npm); `package-lock.json` updates accordingly.

- [ ] **Step 2: Update the test script**

In `backend/package.json`, change:
```json
    "test": "echo \"Error: no test specified\" && exit 1",
```
to:
```json
    "test": "jest",
```

- [ ] **Step 3: Write the failing test**

Create `backend/tests/post.model.test.js`:

```js
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
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd backend && npx jest tests/post.model.test.js`
Expected: FAIL — `Cannot find module '../models/post.model'`.

- [ ] **Step 5: Create the Post model**

Create `backend/models/post.model.js`:

```js
const mongoose = require('mongoose');

const postSchema = new mongoose.Schema({
    type: {
        type: String,
        enum: ['photo', 'video', 'text', 'audio'],
        required: true,
    },
    caption: {
        type: String,
        required: false,
    },
    mediaUrl: {
        type: String,
        required: false,
    },
    audioTitle: {
        type: String,
        required: false,
    },
    durationSeconds: {
        type: Number,
        required: false,
    },
    authorUserId: {
        type: String,
        required: true,
    },
    authorName: {
        type: String,
        required: true,
    },
    likedBy: {
        type: [String],
        default: [],
    },
    commentCount: {
        type: Number,
        default: 0,
    },
    isDeleted: {
        type: Boolean,
        default: false,
    },
}, {
    timestamps: true,
});

module.exports = mongoose.model('Post', postSchema);
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd backend && npx jest tests/post.model.test.js`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
cd backend
git add package.json package-lock.json models/post.model.js tests/post.model.test.js
git commit -m "feat(posts): add Post model and Jest/Supertest/mongodb-memory-server tooling"
```

---

### Task 2: `POST /api/posts` — create a post, with media upload

**Files:**
- Modify: `backend/index.js` (testability refactor at the bottom; new `postUpload` multer instance; new `POST /api/posts` route; new `Post` model require)
- Test: `backend/tests/posts.create.test.js`
- Test fixtures: `backend/tests/fixtures/tiny.png`, `backend/tests/fixtures/not-media.txt`

**Interfaces:**
- Consumes: `Post` model (Task 1).
- Produces: `POST /api/posts` (multipart form: `type`, `caption`?, `authorUserId`, `authorName`, `audioTitle`?, `durationSeconds`?, `media` file field for non-text types) → `201` with the created post JSON, or `400`/`415`/`413` on validation/upload failure. `module.exports = app;` from `backend/index.js` — consumed by Tasks 3-5's tests (and this task's own).

- [ ] **Step 1: Create test fixture files**

Run:
```bash
mkdir -p backend/tests/fixtures
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=" | base64 -d > backend/tests/fixtures/tiny.png
echo "just some plain text, not a media file" > backend/tests/fixtures/not-media.txt
```
Expected: `backend/tests/fixtures/tiny.png` is a valid, tiny (1x1) PNG; `backend/tests/fixtures/not-media.txt` is a plain text file.

- [ ] **Step 2: Write the failing tests**

Create `backend/tests/posts.create.test.js`:

```js
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd backend && npx jest tests/posts.create.test.js`
Expected: FAIL — `POST /api/posts` doesn't exist yet (404s across the board).

- [ ] **Step 4: Testability refactor — export `app`, guard `app.listen`**

At the very bottom of `backend/index.js`, find:

```js
// Global error handler — catches Multer rejections and other middleware errors
app.use((err, req, res, next) => {
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ message: 'File too large. Maximum size is 5 MB.' });
  }
  if (err.message && err.message.includes('Only JPEG')) {
    return res.status(415).json({ message: err.message });
  }
  console.error(err);
  res.status(500).json({ message: 'Internal server error' });
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
```

Replace it with:

```js
// Global error handler — catches Multer rejections and other middleware errors
app.use((err, req, res, next) => {
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ message: 'File too large.' });
  }
  if (err.message && (err.message.includes('Only JPEG') || err.message.includes('Unsupported media type'))) {
    return res.status(415).json({ message: err.message });
  }
  console.error(err);
  res.status(500).json({ message: 'Internal server error' });
});

if (require.main === module) {
  app.listen(PORT, () => {
      console.log(`Server is running on port ${PORT}`);
  });
}

module.exports = app;
```

(This lets `require('../index')` from a test load the app and its routes without starting a real network listener; running `node index.js` or `npm run dev` directly is unaffected since `require.main === module` is true in that case.)

- [ ] **Step 5: Add the second multer instance and the create-post route**

In `backend/index.js`, find the existing multer setup (the block defining `ALLOWED_MIME_TYPES` and `const upload = multer({...})`), and immediately after it, add:

```js
// Multer instance for post media (photo/video/audio) — separate from the
// image-only `upload` above, which stays untouched for /api/upload.
const POST_MEDIA_LIMITS = {
  'image/jpeg': 5 * 1024 * 1024,
  'image/png': 5 * 1024 * 1024,
  'image/webp': 5 * 1024 * 1024,
  'image/gif': 5 * 1024 * 1024,
  'video/mp4': 50 * 1024 * 1024,
  'video/quicktime': 50 * 1024 * 1024,
  'audio/mpeg': 15 * 1024 * 1024,
  'audio/mp4': 15 * 1024 * 1024,
  'audio/wav': 15 * 1024 * 1024,
};

const postUpload = multer({
  storage: storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // largest individual type limit below; per-type limits enforced in the route handler
  fileFilter: function (req, file, cb) {
    if (Object.prototype.hasOwnProperty.call(POST_MEDIA_LIMITS, file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`Unsupported media type: ${file.mimetype}`));
    }
  },
});
```

Then, immediately before the `// Global error handler` comment at the bottom of the file, add:

```js
// ── Posts ──────────────────────────────────────────────────────────────────
const Post = require('./models/post.model');

app.post('/api/posts', postUpload.single('media'), async (req, res) => {
  try {
    const { type, caption, authorUserId, authorName, audioTitle, durationSeconds } = req.body;

    if (!type || !['photo', 'video', 'text', 'audio'].includes(type)) {
      return res.status(400).json({ message: 'type must be one of: photo, video, text, audio' });
    }
    if (!authorUserId || !authorName) {
      return res.status(400).json({ message: 'authorUserId and authorName are required' });
    }
    if (type !== 'text' && !req.file) {
      return res.status(400).json({ message: 'media file is required for photo, video, and audio posts' });
    }

    if (req.file) {
      const perTypeLimit = POST_MEDIA_LIMITS[req.file.mimetype];
      if (req.file.size > perTypeLimit) {
        fs.unlinkSync(req.file.path);
        return res.status(400).json({
          message: `File too large for ${req.file.mimetype}. Maximum size is ${Math.round(perTypeLimit / (1024 * 1024))} MB.`,
        });
      }
    }

    const post = new Post({
      type,
      caption,
      mediaUrl: req.file ? `/uploads/${req.file.filename}` : undefined,
      audioTitle,
      durationSeconds: durationSeconds ? Number(durationSeconds) : undefined,
      authorUserId,
      authorName,
    });
    await post.save();
    res.status(201).json(post);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd backend && npx jest tests/posts.create.test.js`
Expected: PASS (6 tests).

- [ ] **Step 7: Commit**

```bash
cd backend
git add index.js tests/posts.create.test.js tests/fixtures
git commit -m "feat(posts): add POST /api/posts with photo/video/audio/text upload support"
```

---

### Task 3: `GET /api/posts` — paginated feed

**Files:**
- Modify: `backend/index.js` (new route, in the `// ── Posts ──` block from Task 2)
- Test: `backend/tests/posts.feed.test.js`

**Interfaces:**
- Consumes: `Post` model (Task 1), `app` export (Task 2).
- Produces: `GET /api/posts?page=&limit=` → `{ posts, totalPages, currentPage, totalPosts }`, newest-first, excluding `isDeleted: true` documents.

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/posts.feed.test.js`:

```js
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && npx jest tests/posts.feed.test.js`
Expected: FAIL — `GET /api/posts` doesn't exist yet (404s).

- [ ] **Step 3: Add the feed route**

In `backend/index.js`, in the `// ── Posts ──` block (right after the `POST /api/posts` route from Task 2), add:

```js
app.get('/api/posts', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const filter = { isDeleted: false };

    const totalPosts = await Post.countDocuments(filter);
    const totalPages = Math.ceil(totalPosts / limit);

    const posts = await Post.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    res.json({ posts, totalPages, currentPage: page, totalPosts });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && npx jest tests/posts.feed.test.js`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd backend
git add index.js tests/posts.feed.test.js
git commit -m "feat(posts): add GET /api/posts paginated feed"
```

---

### Task 4: `POST /api/posts/:id/like` — like/unlike toggle

**Files:**
- Modify: `backend/index.js` (new route, in the `// ── Posts ──` block)
- Test: `backend/tests/posts.like.test.js`

**Interfaces:**
- Consumes: `Post` model (Task 1), `app` export (Task 2).
- Produces: `POST /api/posts/:id/like` (body `{ userId }`) → `{ liked: boolean, likeCount: number }`, `404` if the post doesn't exist or is soft-deleted, `400` if `userId` is missing.

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/posts.like.test.js`:

```js
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
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && npx jest tests/posts.like.test.js`
Expected: FAIL — `POST /api/posts/:id/like` doesn't exist yet (404s for reasons other than the intended "post not found" case).

- [ ] **Step 3: Add the like-toggle route**

In `backend/index.js`, in the `// ── Posts ──` block (after the `GET /api/posts` route from Task 3), add:

```js
app.post('/api/posts/:id/like', async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }

    // Atomic find-then-save (read likedBy, mutate in JS, write the whole
    // array back) has a lost-update race under concurrent likes on the same
    // post: two concurrent requests can both read the same "before" array
    // and one write can silently clobber the other. This codebase already
    // has an atomic pattern for the same class of operation (see
    // /api/wishlist/add's $addToSet and /api/wishlist/remove's $pull) --
    // reused here as two atomic attempts (add if absent, else remove if
    // present) so every mutation is a single atomic MongoDB operation, not
    // a read-modify-write cycle.
    let post = await Post.findOneAndUpdate(
      { _id: req.params.id, isDeleted: false, likedBy: { $ne: userId } },
      { $addToSet: { likedBy: userId } },
      { new: true }
    );

    let liked = true;
    if (!post) {
      post = await Post.findOneAndUpdate(
        { _id: req.params.id, isDeleted: false, likedBy: userId },
        { $pull: { likedBy: userId } },
        { new: true }
      );
      liked = false;
    }

    if (!post) {
      return res.status(404).json({ message: 'Post not found' });
    }

    res.json({ liked, likeCount: post.likedBy.length });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && npx jest tests/posts.like.test.js`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd backend
git add index.js tests/posts.like.test.js
git commit -m "feat(posts): add POST /api/posts/:id/like toggle"
```

---

### Task 5: `DELETE /api/posts/:id` — author-only soft delete

**Files:**
- Modify: `backend/index.js` (new route, in the `// ── Posts ──` block)
- Test: `backend/tests/posts.delete.test.js`

**Interfaces:**
- Consumes: `Post` model (Task 1), `app` export (Task 2), `GET /api/posts` (Task 3, to verify exclusion after delete).
- Produces: `DELETE /api/posts/:id` (body `{ authorUserId }`) → `200` on success, `403` if `authorUserId` doesn't match the post's author, `404` if the post doesn't exist, `400` if `authorUserId` is missing.

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/posts.delete.test.js`:

```js
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && npx jest tests/posts.delete.test.js`
Expected: FAIL — `DELETE /api/posts/:id` doesn't exist yet.

- [ ] **Step 3: Add the soft-delete route**

In `backend/index.js`, in the `// ── Posts ──` block (after the like-toggle route from Task 4), add:

```js
app.delete('/api/posts/:id', async (req, res) => {
  try {
    const { authorUserId } = req.body;
    if (!authorUserId) {
      return res.status(400).json({ message: 'authorUserId is required' });
    }

    const post = await Post.findOne({ _id: req.params.id, isDeleted: false });
    if (!post) {
      return res.status(404).json({ message: 'Post not found' });
    }

    if (post.authorUserId !== authorUserId) {
      return res.status(403).json({ message: 'Only the author can delete this post' });
    }

    post.isDeleted = true;
    await post.save();

    res.json({ message: 'Post deleted' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && npx jest tests/posts.delete.test.js`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the full Posts test suite together**

Run: `cd backend && npx jest tests/post.model.test.js tests/posts.create.test.js tests/posts.feed.test.js tests/posts.like.test.js tests/posts.delete.test.js`
Expected: PASS (19 tests total: 3 + 6 + 3 + 3 + 4).

- [ ] **Step 6: Commit**

```bash
cd backend
git add index.js tests/posts.delete.test.js
git commit -m "feat(posts): add DELETE /api/posts/:id author-only soft delete"
```

---

## Manual verification (no automated task)

After all 5 tasks are done:
- Start the backend locally (`cd backend && npm run dev`) against a real (or local) MongoDB.
- Using `curl` or Postman: create one post of each type (text without a file; photo/video/audio with a real small file of the matching type), confirm the video/audio files actually upload and `mediaUrl` serves correctly from `/uploads/...`.
- Fetch `GET /api/posts`, confirm pagination and ordering.
- Like/unlike a post twice, confirm the toggle and count.
- Delete a post as its author, confirm it disappears from the feed; attempt to delete it again or as a different `authorUserId`, confirm 403/404 as expected.
