// Rewrites stored user ids to their canonical form (see lib/phone.js) so data
// written under '263…' or '+263…' is found by the canonical identity.
//
// Usage (from backend/):
//   node scripts/migrate-canonical-userids.js          dry run: prints counts only
//   node scripts/migrate-canonical-userids.js --apply  performs the writes
//
// Cart and Wishlist hold one document per user. If a document already exists under
// the canonical id, the non-canonical one is not merged: it is counted as a conflict
// and left as it is for manual review. Output never includes ids.
const mongoose = require('mongoose');
const { canonicalUsername } = require('../lib/phone');
const Cart = require('../models/cart.model');
const Wishlist = require('../models/wishlist.model');
const Order = require('../models/order.model');
const ShippingAddress = require('../models/shipping_address.model');
const Post = require('../models/post.model');

const needsRewrite = (value) => typeof value === 'string' && canonicalUsername(value) !== value;

// Collections with one document per user: skip when the canonical id is taken.
async function migrateUnique(Model, field, apply) {
  const result = { rewritten: 0, conflicts: 0 };
  const docs = await Model.collection.find({}, { projection: { [field]: 1 } }).toArray();
  const existing = new Set(docs.map((d) => d[field]));
  for (const doc of docs) {
    const value = doc[field];
    if (!needsRewrite(value)) continue;
    const target = canonicalUsername(value);
    if (existing.has(target)) {
      result.conflicts += 1;
      continue;
    }
    existing.add(target);
    if (apply) await Model.collection.updateOne({ _id: doc._id }, { $set: { [field]: target } });
    result.rewritten += 1;
  }
  return result;
}

async function migrateField(Model, field, apply) {
  const result = { rewritten: 0, conflicts: 0 };
  const docs = await Model.collection.find({}, { projection: { [field]: 1 } }).toArray();
  for (const doc of docs) {
    const value = doc[field];
    if (!needsRewrite(value)) continue;
    if (apply) {
      await Model.collection.updateOne(
        { _id: doc._id },
        { $set: { [field]: canonicalUsername(value) } }
      );
    }
    result.rewritten += 1;
  }
  return result;
}

// Post.likedBy: rewrite entries and drop duplicates that collapse to one identity.
async function migrateLikedBy(apply) {
  const result = { rewritten: 0, conflicts: 0 };
  const docs = await Post.collection.find({}, { projection: { likedBy: 1 } }).toArray();
  for (const doc of docs) {
    const likedBy = Array.isArray(doc.likedBy) ? doc.likedBy : [];
    if (!likedBy.some(needsRewrite)) continue;
    const next = [...new Set(likedBy.map((v) => (typeof v === 'string' ? canonicalUsername(v) : v)))];
    if (apply) await Post.collection.updateOne({ _id: doc._id }, { $set: { likedBy: next } });
    result.rewritten += 1;
  }
  return result;
}

async function migrate({ apply = false } = {}) {
  return {
    'Cart.userId': await migrateUnique(Cart, 'userId', apply),
    'Wishlist.userId': await migrateUnique(Wishlist, 'userId', apply),
    'Order.user_id': await migrateField(Order, 'user_id', apply),
    'ShippingAddress.userId': await migrateField(ShippingAddress, 'userId', apply),
    'Post.authorUserId': await migrateField(Post, 'authorUserId', apply),
    'Post.likedBy': await migrateLikedBy(apply),
  };
}

async function main() {
  require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
  const apply = process.argv.includes('--apply');
  if (!process.env.MONGO_URI) throw new Error('MONGO_URI must be set');
  await mongoose.connect(process.env.MONGO_URI);
  try {
    const report = await migrate({ apply });
    const verb = apply ? 'rewritten' : 'to rewrite';
    process.stdout.write(apply ? 'Applied.\n' : 'Dry run. Nothing written; pass --apply to write.\n');
    for (const [name, r] of Object.entries(report)) {
      process.stdout.write(`${name}: ${r.rewritten} documents ${verb}, ${r.conflicts} conflicts skipped\n`);
    }
  } finally {
    await mongoose.disconnect();
  }
}

if (require.main === module) {
  main().catch((err) => {
    process.stderr.write(`${err.message}\n`);
    process.exit(1);
  });
}

module.exports = { migrate };
