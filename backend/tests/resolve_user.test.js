const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;
let app;
let mw;
let Product;
let Cart;
let Order;
let Post;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  mw = require('../middleware/auth.middleware');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  Product = require('../models/product.model');
  Cart = require('../models/cart.model');
  Order = require('../models/order.model');
  Post = require('../models/post.model');
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  delete process.env.LEGACY_USERID_ROUTES;
  await Product.deleteMany({});
  await Cart.deleteMany({});
  await Order.deleteMany({});
  await Post.deleteMany({});
});

const tokenFor = (sipUsername) =>
  mw.signAppToken({ _id: new mongoose.Types.ObjectId(), sipUsername });
const bearer = (sipUsername) => `Bearer ${tokenFor(sipUsername)}`;

const makeProduct = () => Product.create({ name: 'Widget', price: 5 });

describe('resolveUser on user-scoped routes', () => {
  test('cart uses token identity', async () => {
    const product = await makeProduct();

    const add = await request(app)
      .post('/api/cart/add')
      .set('Authorization', bearer('A'))
      .send({ productId: String(product._id), quantity: 2 });
    expect(add.status).toBe(200);

    const res = await request(app).get('/api/cart').set('Authorization', bearer('A'));
    expect(res.status).toBe(200);
    expect(res.body.user_id).toBe('A');
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0].quantity).toBe(2);
  });

  test('token wins over body userId', async () => {
    const product = await makeProduct();

    const add = await request(app)
      .post('/api/cart/add')
      .set('Authorization', bearer('A'))
      .send({ userId: 'B', productId: String(product._id) });
    expect(add.status).toBe(200);

    expect(await Cart.findOne({ userId: 'A' })).not.toBeNull();
    expect(await Cart.findOne({ userId: 'B' })).toBeNull();

    const bCart = await request(app).get('/api/cart').set('Authorization', bearer('B'));
    expect(bCart.body.items).toHaveLength(0);
  });

  test('no token returns 401 when legacy off', async () => {
    const res = await request(app).get('/api/cart?userId=A');
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ message: 'Sign in required.' });
  });

  test('no token with legacy on uses body userId', async () => {
    process.env.LEGACY_USERID_ROUTES = 'true';
    const product = await makeProduct();

    const add = await request(app)
      .post('/api/cart/add')
      .send({ userId: 'legacyUser', productId: String(product._id) });
    expect(add.status).toBe(200);
    expect(await Cart.findOne({ userId: 'legacyUser' })).not.toBeNull();
  });

  test('legacy fallback canonicalises a phone-number user id', async () => {
    process.env.LEGACY_USERID_ROUTES = 'true';
    const product = await makeProduct();

    const add = await request(app)
      .post('/api/cart/add')
      .send({ userId: '263771234567', productId: String(product._id) });
    expect(add.status).toBe(200);
    expect(await Cart.findOne({ userId: '+263771234567' })).not.toBeNull();
    expect(await Cart.findOne({ userId: '263771234567' })).toBeNull();

    const res = await request(app).get('/api/cart?userId=%2B263771234567');
    expect(res.body.items).toHaveLength(1);
  });

  test('legacy flag only accepts the exact string "true"', async () => {
    process.env.LEGACY_USERID_ROUTES = '1';
    const res = await request(app).get('/api/cart?userId=A');
    expect(res.status).toBe(401);
  });

  test('invalid token returns 401 even with legacy on', async () => {
    process.env.LEGACY_USERID_ROUTES = 'true';
    const res = await request(app)
      .get('/api/cart?userId=A')
      .set('Authorization', 'Bearer not-a-real-token');
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ message: 'Sign in required.' });
  });

  test('admin token is not accepted as an app identity', async () => {
    const admin = mw.signAdminToken({ _id: new mongoose.Types.ObjectId(), role: 'staff', username: 'A' });
    const res = await request(app).get('/api/cart').set('Authorization', `Bearer ${admin}`);
    expect(res.status).toBe(401);
  });

  test("orders GET only returns caller's orders", async () => {
    const created = await request(app)
      .post('/api/orders')
      .set('Authorization', bearer('A'))
      .send({ userId: 'B', items: [{ product: { name: 'Widget' }, quantity: 1, total: 5 }], total: 5 });
    expect(created.status).toBe(201);
    expect(created.body.user_id).toBe('A');

    await Order.create({
      order_id: 'order_other', user_id: 'B', total_amount: 3,
      items: [{ product: { name: 'X' }, quantity: 1, total: 3 }],
    });

    const res = await request(app)
      .get('/api/orders?userId=B')
      .set('Authorization', bearer('A'));
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body.every((o) => o.user_id === 'A')).toBe(true);
  });

  test('post delete by non-author is 403 (author from token)', async () => {
    const post = await Post.create({
      type: 'text', caption: 'mine', authorUserId: 'A', authorName: 'Alice',
    });

    const res = await request(app)
      .delete(`/api/posts/${post._id}`)
      .set('Authorization', bearer('B'))
      .send({ authorUserId: 'A' });
    expect(res.status).toBe(403);

    const stillThere = await Post.findById(post._id);
    expect(stillThere.isDeleted).toBe(false);
  });

  test('post create takes author from token, not the form field', async () => {
    const res = await request(app)
      .post('/api/posts')
      .set('Authorization', bearer('A'))
      .field('type', 'text')
      .field('caption', 'hello')
      .field('authorUserId', 'B')
      .field('authorName', 'Alice');
    expect(res.status).toBe(201);
    expect(res.body.authorUserId).toBe('A');
  });

  test('unauthenticated post upload is rejected and its file is not kept', async () => {
    const fs = require('fs');
    const path = require('path');
    const uploads = path.join(process.cwd(), 'uploads');
    const before = new Set(fs.readdirSync(uploads));

    const res = await request(app)
      .post('/api/posts')
      .field('type', 'photo')
      .field('authorUserId', 'A')
      .field('authorName', 'Alice')
      .attach('media', path.join(__dirname, 'fixtures', 'tiny.png'));
    expect(res.status).toBe(401);

    const added = fs.readdirSync(uploads).filter((f) => !before.has(f));
    expect(added).toEqual([]);
  });

  test('product browse works anonymously', async () => {
    await makeProduct();
    const res = await request(app).get('/api/products');
    expect(res.status).toBe(200);
    expect(res.body.totalProducts).toBe(1);
  });

  test('product browse ignores an invalid token instead of rejecting', async () => {
    await makeProduct();
    const res = await request(app)
      .get('/api/products?sort=recommended')
      .set('Authorization', 'Bearer not-a-real-token');
    expect(res.status).toBe(200);
    expect(res.body.totalProducts).toBe(1);
  });
});

describe('req.auth from resolveUser', () => {
  const { resolveUser } = require('../middleware/resolve_user.middleware');

  // Runs the middleware on a fake request; resolves with next() or the rejection status.
  const call = (opts, req) => {
    const mwReq = { headers: {}, query: {}, body: {}, ...req };
    return new Promise((resolve) => {
      const res = { status: (code) => ({ json: () => resolve({ status: code, req: mwReq }) }) };
      resolveUser(opts)(mwReq, res, () => resolve({ next: true, req: mwReq }));
    });
  };

  test('token request: via token with the token subject', async () => {
    const id = new mongoose.Types.ObjectId();
    const token = mw.signAppToken({ _id: id, sipUsername: '+263771234567' });
    const out = await call(
      { field: 'userId' },
      { headers: { authorization: `Bearer ${token}` } }
    );
    expect(out.next).toBe(true);
    expect(out.req.userId).toBe('+263771234567');
    expect(out.req.auth).toEqual({ via: 'token', appUserId: String(id) });
  });

  test('legacy request: via legacy, no app user id', async () => {
    process.env.LEGACY_USERID_ROUTES = 'true';
    const out = await call({ field: 'userId' }, { body: { userId: '263771234567' } });
    expect(out.next).toBe(true);
    expect(out.req.userId).toBe('+263771234567');
    expect(out.req.auth).toEqual({ via: 'legacy' });
  });

  test('anonymous request on an optional route: req.auth undefined', async () => {
    process.env.LEGACY_USERID_ROUTES = 'true';
    const out = await call({ field: 'userId', required: false }, {});
    expect(out.next).toBe(true);
    expect(out.req.userId).toBeUndefined();
    expect(out.req.auth).toBeUndefined();

    const invalid = await call(
      { field: 'userId', required: false },
      { headers: { authorization: 'Bearer not-a-real-token' } }
    );
    expect(invalid.next).toBe(true);
    expect(invalid.req.auth).toBeUndefined();
  });
});

describe('GET /api/admin/legacy-usage', () => {
  const adminToken = (role) =>
    mw.signAdminToken({ _id: new mongoose.Types.ObjectId(), role, username: `${role}1` });
  const usage = (token) => {
    const r = request(app).get('/api/admin/legacy-usage');
    return token ? r.set('Authorization', `Bearer ${token}`) : r;
  };

  test('counts token and legacy requests; super_admin only', async () => {
    const before = await usage(adminToken('super_admin'));
    expect(before.status).toBe(200);
    expect(Object.keys(before.body).sort()).toEqual(['legacyRequests', 'since', 'tokenRequests']);
    expect(Number.isNaN(Date.parse(before.body.since))).toBe(false);

    await request(app).get('/api/cart').set('Authorization', bearer('A'));
    process.env.LEGACY_USERID_ROUTES = 'true';
    await request(app).get('/api/cart?userId=B');
    await request(app).get('/api/cart?userId=C');
    await request(app).get('/api/products'); // anonymous: counted as neither

    const after = await usage(adminToken('super_admin'));
    expect(after.body.tokenRequests - before.body.tokenRequests).toBe(1);
    expect(after.body.legacyRequests - before.body.legacyRequests).toBe(2);
    expect(after.body.since).toBe(before.body.since);

    expect((await usage(adminToken('staff'))).status).toBe(403);
    expect((await usage(tokenFor('A'))).status).toBe(401);
    expect((await usage()).status).toBe(401);
  });
});
