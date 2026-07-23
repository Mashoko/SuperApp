require('dotenv').config();
const mongoose = require('mongoose');
const Faq = require('../models/faq.model');
const faqSeedData = require('./faq-seed-data');

async function seed() {
  await mongoose.connect(process.env.MONGO_URI);

  for (const category of faqSeedData) {
    await Faq.findOneAndUpdate(
      { title: category.title },
      category,
      { upsert: true, new: true }
    );
    console.log(`Seeded: ${category.title} (${category.items.length} items)`);
  }

  await mongoose.disconnect();
  console.log('Done.');
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
