const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { migrate } = require('../scripts/migrate-canonical-userids');
const Cart = require('../models/cart.model');
const Wishlist = require('../models/wishlist.model');
const Order = require('../models/order.model');
const ShippingAddress = require('../models/shipping_address.model');
const Post = require('../models/post.model');

let mongoServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());
  await Promise.all([Cart.init(), Wishlist.init()]);
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

beforeEach(async () => {
  await Promise.all([Cart, Wishlist, Order, ShippingAddress, Post].map((M) => M.deleteMany({})));
  await Cart.create([
    { userId: '263771111111', items: [] }, // rewrite
    { userId: '263772222222', items: [] }, // conflict: canonical already exists
    { userId: '+263772222222', items: [] },
    { userId: 'alice', items: [] }, // non-phone, untouched
  ]);
  await Wishlist.create([
    { userId: '263773333333', productIds: [] },
    { userId: '263774444444', productIds: [] },
    { userId: '+263774444444', productIds: [] },
  ]);
  await Order.create([
    { order_id: 'o1', user_id: '263771111111', total_amount: 1, items: [] },
    { order_id: 'o2', user_id: '+263771111111', total_amount: 1, items: [] },
  ]);
  await ShippingAddress.create({ userId: '263 77 111 1111', label: 'Home', address: 'x' });
  await Post.create([
    { type: 'text', authorUserId: '263771111111', authorName: 'A', likedBy: ['263772222222', '+263772222222', 'bob'] },
    { type: 'text', authorUserId: '+263772222222', authorName: 'B', likedBy: ['+263771111111'] },
  ]);
});

const snapshot = async () => ({
  carts: (await Cart.find().lean()).map((d) => d.userId).sort(),
  wishlists: (await Wishlist.find().lean()).map((d) => d.userId).sort(),
  orders: (await Order.find().lean()).map((d) => d.user_id).sort(),
  addresses: (await ShippingAddress.find().lean()).map((d) => d.userId).sort(),
  posts: (await Post.find().sort({ authorName: 1 }).lean()).map((d) => [d.authorUserId, d.likedBy]),
});

const expectedCounts = {
  'Cart.userId': { rewritten: 1, conflicts: 1 },
  'Wishlist.userId': { rewritten: 1, conflicts: 1 },
  'Order.user_id': { rewritten: 1, conflicts: 0 },
  'ShippingAddress.userId': { rewritten: 1, conflicts: 0 },
  'Post.authorUserId': { rewritten: 1, conflicts: 0 },
  'Post.likedBy': { rewritten: 1, conflicts: 0 },
};

test('dry run reports counts and changes nothing', async () => {
  const before = await snapshot();
  expect(await migrate()).toEqual(expectedCounts);
  expect(await snapshot()).toEqual(before);
});

test('apply rewrites to canonical ids and skips Cart/Wishlist conflicts', async () => {
  expect(await migrate({ apply: true })).toEqual(expectedCounts);
  expect(await snapshot()).toEqual({
    carts: ['+263771111111', '+263772222222', '263772222222', 'alice'],
    wishlists: ['+263773333333', '+263774444444', '263774444444'],
    orders: ['+263771111111', '+263771111111'],
    addresses: ['+263771111111'],
    posts: [
      ['+263771111111', ['+263772222222', 'bob']],
      ['+263772222222', ['+263771111111']],
    ],
  });
  // A second run has nothing left to do except the skipped conflicts.
  const again = await migrate({ apply: true });
  expect(again['Cart.userId']).toEqual({ rewritten: 0, conflicts: 1 });
  expect(again['Order.user_id']).toEqual({ rewritten: 0, conflicts: 0 });
});
