const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { MongoMemoryServer } = require('mongodb-memory-server');
const User = require('../models/user.model');

let mongoServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

test('new staff passwords are hashed with bcrypt cost 12', async () => {
  const user = await User.create({ username: 'staff-cost', password: 'correct horse' });
  expect(bcrypt.getRounds(user.password)).toBe(12);
  expect(await user.comparePassword('correct horse')).toBe(true);
  expect(await user.comparePassword('wrong')).toBe(false);
});

test('existing cost-10 hashes still verify', async () => {
  const legacyHash = await bcrypt.hash('old password', 10);
  await User.collection.insertOne({ username: 'staff-old', password: legacyHash, role: 'staff' });
  const user = await User.findOne({ username: 'staff-old' });
  expect(await user.comparePassword('old password')).toBe(true);
});
