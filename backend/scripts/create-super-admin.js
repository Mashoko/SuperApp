require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const User = require('../models/user.model');

async function run() {
  const { ADMIN_USERNAME, ADMIN_PASSWORD, MONGO_URI } = process.env;
  if (!ADMIN_USERNAME || !ADMIN_PASSWORD) {
    throw new Error('ADMIN_USERNAME and ADMIN_PASSWORD must be set');
  }

  await mongoose.connect(MONGO_URI);

  // Load then save so the model's pre-save hook hashes the password.
  let user = await User.findOne({ username: ADMIN_USERNAME });
  if (!user) user = new User({ username: ADMIN_USERNAME });
  user.password = ADMIN_PASSWORD;
  user.role = 'super_admin';
  await user.save();

  await mongoose.disconnect();
  process.stdout.write(`super_admin ready: ${ADMIN_USERNAME}\n`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
