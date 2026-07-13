const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;
let app;
let Product;
let Wishlist;
let Cart;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  Product = require('../models/product.model');
  Wishlist = require('../models/wishlist.model');
  Cart = require('../models/cart.model');
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await Product.deleteMany({});
  await Wishlist.deleteMany({});
  await Cart.deleteMany({});
});

describe('GET /api/products?sort=trending', () => {
  test('returns only isTrending products sorted by rating descending', async () => {
    await Product.create({ name: 'A', price: 10, isTrending: true, averageRating: 3.5 });
    await Product.create({ name: 'B', price: 10, isTrending: true, averageRating: 4.8 });
    await Product.create({ name: 'C', price: 10, isTrending: false, averageRating: 5.0 });

    const res = await request(app).get('/api/products?sort=trending');

    expect(res.status).toBe(200);
    expect(res.body.products).toHaveLength(2);
    expect(res.body.products.map((p) => p.name)).toEqual(['B', 'A']);
  });

  test('returns an empty list (not an error) when no products are trending', async () => {
    await Product.create({ name: 'A', price: 10, isTrending: false });

    const res = await request(app).get('/api/products?sort=trending');

    expect(res.status).toBe(200);
    expect(res.body.products).toEqual([]);
    expect(res.body.totalProducts).toBe(0);
  });
});

describe('GET /api/products?sort=recommended', () => {
  test('recommends products in the same category as the user\'s wishlist, excluding wishlist/cart items', async () => {
    const wishlisted = await Product.create({ name: 'Wishlisted', price: 10, category: 'Shoes' });
    await Product.create({ name: 'Same category', price: 20, category: 'Shoes', averageRating: 4.0 });
    const inCart = await Product.create({ name: 'In cart', price: 15, category: 'Shoes', averageRating: 4.9 });
    await Product.create({ name: 'Other category', price: 30, category: 'Lamps' });

    await Wishlist.create({ userId: 'user1', productIds: [wishlisted._id] });
    await Cart.create({ userId: 'user1', items: [{ productId: inCart._id, quantity: 1 }] });

    const res = await request(app).get('/api/products?sort=recommended&userId=user1');

    expect(res.status).toBe(200);
    const names = res.body.products.map((p) => p.name);
    expect(names).toEqual(['Same category']);
  });

  test('falls back to newest-first when the user has no wishlist items', async () => {
    await Product.create({ name: 'Older', price: 10 });
    await new Promise((resolve) => setTimeout(resolve, 10));
    await Product.create({ name: 'Newer', price: 10 });

    const res = await request(app).get('/api/products?sort=recommended&userId=newuser');

    expect(res.status).toBe(200);
    expect(res.body.products.map((p) => p.name)).toEqual(['Newer', 'Older']);
  });

  test('falls back to newest-first when no userId is supplied', async () => {
    await Product.create({ name: 'Older', price: 10 });
    await new Promise((resolve) => setTimeout(resolve, 10));
    await Product.create({ name: 'Newer', price: 10 });

    const res = await request(app).get('/api/products?sort=recommended');

    expect(res.status).toBe(200);
    expect(res.body.products.map((p) => p.name)).toEqual(['Newer', 'Older']);
  });
});

describe('GET /api/products (no sort param)', () => {
  test('existing pagination/category/search behavior is unchanged', async () => {
    await Product.create({ name: 'A', price: 10, category: 'Shoes' });
    await Product.create({ name: 'B', price: 10, category: 'Lamps' });

    const res = await request(app).get('/api/products?category=Shoes');

    expect(res.status).toBe(200);
    expect(res.body.products).toHaveLength(1);
    expect(res.body.products[0].name).toBe('A');
  });
});
