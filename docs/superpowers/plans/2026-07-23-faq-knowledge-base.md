# FAQ Knowledge Base (Phase 2, Slice 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move FAQ content out of a compiled-in Dart constant into a backend-managed MongoDB collection, editable by admins through a new admin-panel page, and consumed live by both Dash and Help & Support with local caching.

**Architecture:** A new `Faq` Mongoose model + 4 REST routes on the existing Express backend (mirroring the existing `Category` model/routes exactly), a new admin-panel CRUD page (mirroring `categories.html/js`), and a new Flutter `FaqService`/`FaqViewModel` pair that fetches, caches (`SharedPreferences`), and exposes the data — replacing the static `faqData` constant everywhere it's read (`DashViewModel`, Help & Support's FAQ browser/search).

**Tech Stack:** Node/Express/Mongoose (backend, already in place), vanilla JS admin panel (already in place), Flutter/`http`/`shared_preferences`/`provider`/`get_it` (already in place, same conventions as `PostsService`/`AccountSummaryViewModel`).

## Global Constraints

- Backend API base URL (both admin panel and Flutter app): `https://superapp-diht.onrender.com/api` (admin panel auto-detects `localhost:5000/api` in dev — existing `admin-panel/config.js` behavior, unchanged).
- All admin-only routes (`POST`/`PUT`/`DELETE`) go behind the existing `auth.middleware.js` (`backend/middleware/auth.middleware.js`), exactly like `Category`'s routes. `GET /api/faqs` is public, matching `GET /api/categories`.
- Backend model stores content only (`title`, `items[].question`, `items[].answer`) — no icon/color. The Flutter app maps category title → icon/color via a static lookup table with a fallback for unknown titles.
- No backend search endpoint — the full dataset is cached on-device; search stays client-side (unchanged behavior).
- No icon/color picker in the admin UI.
- App caches fetched FAQ content in `SharedPreferences`, serves cached content instantly, refreshes in the background — no blank/loading FAQ experience on every open.
- Flutter package name is `mvvm_sip_demo`.
- Run `dart analyze` (scoped to the files/directories a task touches — some tasks intentionally leave other, not-yet-updated files non-compiling until a later task fixes them; this mirrors the established pattern in this repo's prior plans) after every Flutter task. Run `npm test` (Jest) from `backend/` after every backend task.

---

### Task 1: Backend — `Faq` model + CRUD routes + tests

**Files:**
- Create: `backend/models/faq.model.js`
- Modify: `backend/index.js` (add `require` + 4 routes)
- Test: `backend/tests/faqs.test.js`

**Interfaces:**
- Produces: Mongoose model `Faq` (`title: String`, `items: [{question: String, answer: String}]`, timestamps), routes `GET/POST /api/faqs`, `PUT/DELETE /api/faqs/:id`. Task 2 (seed script) and Task 4 (Flutter `FaqService`) consume this exact JSON shape: `{ _id, title, items: [{ question, answer }], createdAt, updatedAt }`.

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/faqs.test.js`:

```js
const request = require('supertest');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;
let app;
let Faq;
let authToken;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  Faq = require('../models/faq.model');
  authToken = jwt.sign({ id: 'test-admin' }, process.env.JWT_SECRET);
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await Faq.deleteMany({});
});

describe('GET /api/faqs', () => {
  test('returns all FAQ categories, no auth required', async () => {
    await Faq.create({ title: 'Payments', items: [{ question: 'Q1', answer: 'A1' }] });

    const res = await request(app).get('/api/faqs');

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].title).toBe('Payments');
    expect(res.body[0].items[0].question).toBe('Q1');
  });

  test('returns an empty array (not an error) when there are no FAQ categories', async () => {
    const res = await request(app).get('/api/faqs');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});

describe('POST /api/faqs', () => {
  test('rejects the request with no auth token', async () => {
    const res = await request(app)
      .post('/api/faqs')
      .send({ title: 'Wallet', items: [] });
    expect(res.status).toBe(401);
  });

  test('creates a new FAQ category with a valid token', async () => {
    const res = await request(app)
      .post('/api/faqs')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ title: 'Wallet', items: [{ question: 'Q', answer: 'A' }] });

    expect(res.status).toBe(201);
    expect(res.body.title).toBe('Wallet');
    const stored = await Faq.findOne({ title: 'Wallet' });
    expect(stored).not.toBeNull();
  });

  test('rejects a category with no title', async () => {
    const res = await request(app)
      .post('/api/faqs')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ items: [] });
    expect(res.status).toBe(400);
  });
});

describe('PUT /api/faqs/:id', () => {
  test("updates an existing category's items", async () => {
    const faq = await Faq.create({ title: 'General', items: [{ question: 'Old Q', answer: 'Old A' }] });

    const res = await request(app)
      .put(`/api/faqs/${faq._id}`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ title: 'General', items: [{ question: 'New Q', answer: 'New A' }] });

    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0].question).toBe('New Q');
  });

  test('rejects an update with no auth token', async () => {
    const faq = await Faq.create({ title: 'General', items: [] });
    const res = await request(app)
      .put(`/api/faqs/${faq._id}`)
      .send({ title: 'General', items: [] });
    expect(res.status).toBe(401);
  });
});

describe('DELETE /api/faqs/:id', () => {
  test('deletes an existing category', async () => {
    const faq = await Faq.create({ title: 'Temp', items: [] });

    const res = await request(app)
      .delete(`/api/faqs/${faq._id}`)
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    const stored = await Faq.findById(faq._id);
    expect(stored).toBeNull();
  });

  test('rejects a delete with no auth token', async () => {
    const faq = await Faq.create({ title: 'Temp', items: [] });
    const res = await request(app).delete(`/api/faqs/${faq._id}`);
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (from `backend/`): `npx jest tests/faqs.test.js`
Expected: FAIL — `Cannot find module '../models/faq.model'` (model doesn't exist yet)

- [ ] **Step 3: Create the `Faq` model**

Create `backend/models/faq.model.js`:

```js
const mongoose = require('mongoose');

const faqItemSchema = new mongoose.Schema({
    question: { type: String, required: true },
    answer:   { type: String, required: true },
}, { _id: false });

const faqSchema = new mongoose.Schema({
    title: { type: String, required: true, unique: true, trim: true },
    items: [faqItemSchema],
}, {
    timestamps: true
});

module.exports = mongoose.model('Faq', faqSchema);
```

- [ ] **Step 4: Add the routes**

In `backend/index.js`, add the import alongside the other model requires (right after `const Category = require('./models/category.model');` at line 130):

```js
const Faq = require('./models/faq.model');
```

Add the routes right after the `// --- Category Routes ---` block ends (after the `Delete Category` route, right before the `// --- Shop Routes ---` comment):

```js
// --- FAQ Routes ---
// Get all FAQ categories
app.get('/api/faqs', async (req, res) => {
    try {
        const faqs = await Faq.find();
        res.json(faqs);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Create FAQ category
app.post('/api/faqs', auth, async (req, res) => {
    const faq = new Faq(req.body);
    try {
        const newFaq = await faq.save();
        res.status(201).json(newFaq);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Update FAQ category
app.put('/api/faqs/:id', auth, async (req, res) => {
    try {
        const updatedFaq = await Faq.findByIdAndUpdate(req.params.id, req.body, { new: true });
        res.json(updatedFaq);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Delete FAQ category
app.delete('/api/faqs/:id', auth, async (req, res) => {
    try {
        await Faq.findByIdAndDelete(req.params.id);
        res.json({ message: 'FAQ category deleted' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});
```

- [ ] **Step 5: Run the tests to verify they pass**

Run (from `backend/`): `npx jest tests/faqs.test.js`
Expected: `Tests: 9 passed, 9 total`

- [ ] **Step 6: Commit**

```bash
git add backend/models/faq.model.js backend/index.js backend/tests/faqs.test.js
git commit -m "feat(backend): add Faq model and CRUD routes"
```

---

### Task 2: Backend — seed data + one-time migration script

**Files:**
- Create: `backend/scripts/faq-seed-data.js`
- Create: `backend/scripts/seed-faqs.js`
- Test: `backend/tests/faq-seed-data.test.js`

**Interfaces:**
- Consumes: `Faq` model (Task 1).
- Produces: `backend/scripts/faq-seed-data.js` exports an array of `{ title, items: [{question, answer}] }` — the exact content currently in `lib/features/help_support/data/faq_data.dart`'s `faqData` constant, transcribed losslessly. This is a manual, one-time migration utility — not part of the app's runtime startup.

- [ ] **Step 1: Write the failing test for the seed data's shape**

Create `backend/tests/faq-seed-data.test.js`:

```js
const faqSeedData = require('../scripts/faq-seed-data');

describe('faqSeedData', () => {
  test('has 7 categories with unique titles', () => {
    expect(faqSeedData).toHaveLength(7);
    const titles = faqSeedData.map((c) => c.title);
    expect(new Set(titles).size).toBe(7);
  });

  test('every category has at least one item with a non-empty question and answer', () => {
    for (const category of faqSeedData) {
      expect(category.items.length).toBeGreaterThan(0);
      for (const item of category.items) {
        expect(item.question.length).toBeGreaterThan(0);
        expect(item.answer.length).toBeGreaterThan(0);
      }
    }
  });

  test('includes the known Payments and General categories', () => {
    const titles = faqSeedData.map((c) => c.title);
    expect(titles).toContain('Payments');
    expect(titles).toContain('General');
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run (from `backend/`): `npx jest tests/faq-seed-data.test.js`
Expected: FAIL — `Cannot find module '../scripts/faq-seed-data'`

- [ ] **Step 3: Create the seed data file**

Create `backend/scripts/faq-seed-data.js` with this exact content — transcribed verbatim (content only; the Flutter source's `icon`/`color` fields are Flutter-only presentation and do not carry over) from `lib/features/help_support/data/faq_data.dart`'s current `faqData` constant:

```js
const faqSeedData = [
  {
    title: 'Payments',
    items: [
      { question: 'Why is my payment pending?', answer: 'Payments can take up to 24 hours to process depending on your bank or mobile money provider. If it has been longer than 24 hours, please use the Report a Problem form and attach your transaction receipt.' },
      { question: 'My payment failed — what now?', answer: 'Check that your card or wallet has sufficient funds and that your payment method is active. Try again or use an alternative method. If the issue persists, tap Report a Problem.' },
      { question: 'I was charged twice', answer: 'Duplicate charges are reversed automatically within 2 business days. If you have not received a refund after 3 days, contact our support team with the duplicate transaction IDs.' },
      { question: 'What is the refund policy?', answer: 'Digital services (calls, airtime) are non-refundable once delivered. Shopping orders can be refunded within 7 days of delivery if the item is unused and in original condition.' },
      { question: 'My card was declined', answer: 'Ensure your card is enabled for online payments. Some cards block international or digital transactions by default — contact your bank to enable them.' },
      { question: 'What are the transaction limits?', answer: 'Daily limits vary by payment method. EcoCash: $500/day. Bank cards: $2,000/day. Wallet transfers: $1,000/day. Contact support to request a limit increase.' },
    ],
  },
  {
    title: 'Shopping',
    items: [
      { question: 'How do I track my order?', answer: 'Go to Profile → My Orders and tap on your order. You will see the real-time status and estimated delivery date.' },
      { question: 'My order has not arrived', answer: 'Check the tracking status in My Orders. If the delivery window has passed, tap Report a Problem and select Shopping to raise an investigation.' },
      { question: 'How do I return an item?', answer: 'Visit My Orders, tap the order, and select Return Item. Returns must be requested within 7 days of delivery. The seller will arrange collection.' },
      { question: 'Can I cancel my order?', answer: 'Orders can be cancelled within 30 minutes of placement before they are confirmed by the seller. Go to My Orders → Cancel Order.' },
      { question: 'I received the wrong item', answer: 'Take a photo of the received item and tap Report a Problem → Shopping → Wrong Item Received. We will arrange a replacement or refund.' },
      { question: 'Where is my refund?', answer: 'Approved refunds are processed within 3–5 business days back to your original payment method.' },
    ],
  },
  {
    title: 'Calling & Airtime',
    items: [
      { question: 'How do I buy airtime?', answer: 'Tap the Calling tab → Buy Airtime, enter the amount and recipient number, then confirm payment.' },
      { question: 'I sent airtime to the wrong number', answer: 'Airtime transfers are instant and cannot be reversed. Please double-check the number before confirming a transfer.' },
      { question: 'Poor call quality', answer: 'VoIP call quality depends on your internet connection. For best results use Wi-Fi or a strong 4G signal. Try toggling airplane mode to reset your connection.' },
      { question: 'My calls are dropping', answer: 'Check your internet speed (minimum 1 Mbps for calls). If the issue persists, go to Account Services and re-register your SIP account.' },
      { question: 'International calls not connecting', answer: 'Ensure your account has sufficient balance and that the destination number is formatted correctly with the country code (e.g. +44 for UK).' },
      { question: 'I was not credited after recharge', answer: 'Wait 5 minutes and pull-to-refresh your balance. If the credit still has not appeared, report the issue with your voucher PIN and transaction reference.' },
    ],
  },
  {
    title: 'Wallet',
    items: [
      { question: 'How do I deposit into my wallet?', answer: 'Tap Payment Methods → Add Funds and choose EcoCash, OneMoney, or bank transfer. Deposits reflect within minutes.' },
      { question: 'How do I withdraw from my wallet?', answer: 'Tap Wallet → Withdraw and select your bank account or mobile money number. Withdrawals take 1–2 business days.' },
      { question: 'My wallet balance is incorrect', answer: 'Pull down to refresh your wallet. If the balance is still wrong after refreshing, contact support with the specific transaction ID.' },
      { question: 'Can I send money to another user?', answer: 'Wallet transfers between app users are instant. Tap Wallet → Transfer and enter the recipient\'s phone number.' },
      { question: 'What are the wallet limits?', answer: 'The daily spending limit is $2,000 and the wallet balance cap is $5,000. Contact support to request an increase.' },
      { question: 'Why is my wallet frozen?', answer: 'Wallets are temporarily frozen after suspicious activity is detected. Tap Emergency → Unfreeze Account or contact support directly.' },
    ],
  },
  {
    title: 'Utility Bills',
    items: [
      { question: 'How do I pay ZESA?', answer: 'Tap Bills → Electricity → ZESA, enter your meter number and amount, then confirm payment. The token is delivered by SMS.' },
      { question: 'I paid but did not receive my ZESA token', answer: 'Tokens are usually delivered within 2 minutes. Check your SMS inbox. If not received after 10 minutes, tap Report a Problem → Utility Bills.' },
      { question: 'Can I pay bills for someone else?', answer: 'Yes. During payment, enter the recipient\'s account number or meter number instead of your own.' },
      { question: 'Which utility providers are supported?', answer: 'ZESA, ZINWA, DSTV, ZOL, TelOne, NetOne, Econet, Municipality rates, and selected school fees.' },
      { question: 'My bill payment is pending', answer: 'Some payments to utility providers take up to 30 minutes to process. If it is pending for more than 1 hour, report the issue with your reference number.' },
      { question: 'Can I set up recurring bill payments?', answer: 'Recurring payments are coming soon. You will be notified when the feature is available.' },
    ],
  },
  {
    title: 'Account & Security',
    items: [
      { question: 'How do I reset my PIN?', answer: 'Tap Profile → Account Services → Reset PIN. You will receive an OTP on your registered phone number to verify your identity.' },
      { question: 'How do I change my phone number?', answer: 'Phone number changes require identity verification. Contact support with a copy of your ID and proof of ownership of the new number.' },
      { question: 'I cannot log in to my account', answer: 'Tap Forgot Password on the login screen to reset via OTP. If you no longer have access to your registered number, contact support immediately.' },
      { question: 'How do I enable two-factor authentication?', answer: 'Go to Profile → Settings → Security → Two-Factor Authentication and follow the setup steps.' },
      { question: 'I suspect unauthorized access to my account', answer: 'Immediately tap Emergency → Account Compromised. This will lock your account and alert our security team.' },
      { question: 'How do I delete my account?', answer: 'Account deletion requests must be submitted in writing to support@firststreet.co.zw with your full name and registered phone number.' },
    ],
  },
  {
    title: 'General',
    items: [
      { question: 'What is First Street?', answer: 'First Street is a super app providing calling, shopping, utility bill payments, and wallet services across Zimbabwe and the region.' },
      { question: 'Is my data secure?', answer: 'Yes. All data is encrypted in transit and at rest. We comply with applicable data protection regulations and never sell your personal information.' },
      { question: 'How do I update the app?', answer: 'Open the Google Play Store or Apple App Store and search for First Street to download the latest version.' },
      { question: 'The app is crashing', answer: 'Try force-closing and reopening the app. If the issue continues, uninstall and reinstall from the store. If it still crashes, report the issue.' },
      { question: 'How do I contact support?', answer: 'Use any channel on the Help & Support screen: WhatsApp, live chat, email, or phone. WhatsApp is the fastest.' },
      { question: 'What are support hours?', answer: 'WhatsApp and chat: 24/7. Phone support: Monday–Friday 08:00–17:00 CAT. Email: responses within 24 hours.' },
    ],
  },
];

module.exports = faqSeedData;
```

- [ ] **Step 4: Run the test to verify it passes**

Run (from `backend/`): `npx jest tests/faq-seed-data.test.js`
Expected: `Tests: 3 passed, 3 total`

- [ ] **Step 5: Create the migration script**

Create `backend/scripts/seed-faqs.js`:

```js
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
```

- [ ] **Step 6: Run the migration against a real (dev) database**

Run (from `backend/`, with `MONGO_URI` pointed at a dev/staging database — never production without the user's explicit go-ahead): `node scripts/seed-faqs.js`
Expected: 7 lines of `Seeded: <title> (<n> items)` followed by `Done.`

- [ ] **Step 7: Commit**

```bash
git add backend/scripts/faq-seed-data.js backend/scripts/seed-faqs.js backend/tests/faq-seed-data.test.js
git commit -m "feat(backend): add FAQ seed data and one-time migration script"
```

---

### Task 3: Admin panel — FAQ management page

**Files:**
- Create: `admin-panel/faqs.html`
- Create: `admin-panel/faqs.js`
- Modify: `admin-panel/index.html`, `admin-panel/categories.html`, `admin-panel/shops.html`, `admin-panel/banners.html`, `admin-panel/vouchers.html` (add a "FAQs" nav link to each)

**Interfaces:**
- Consumes: `GET/POST/PUT/DELETE /api/faqs` (Task 1).
- Produces: a working admin CRUD page at `faqs.html`, reachable from every other admin page's sidebar nav.

- [ ] **Step 1: Add the "FAQs" nav link to every existing admin page**

In `admin-panel/index.html`, change:
```html
            <a href="index.html" class="nav-item active">Products</a>
            <a href="categories.html" class="nav-item">Categories</a>
            <a href="shops.html" class="nav-item">Shops</a>
            <a href="banners.html" class="nav-item">Banners</a>
            <a href="vouchers.html" class="nav-item">Vouchers</a>
```
to:
```html
            <a href="index.html" class="nav-item active">Products</a>
            <a href="categories.html" class="nav-item">Categories</a>
            <a href="shops.html" class="nav-item">Shops</a>
            <a href="banners.html" class="nav-item">Banners</a>
            <a href="vouchers.html" class="nav-item">Vouchers</a>
            <a href="faqs.html" class="nav-item">FAQs</a>
```

In `admin-panel/categories.html`, change:
```html
            <a href="index.html" class="nav-item">Products</a>
            <a href="categories.html" class="nav-item active">Categories</a>
            <a href="shops.html" class="nav-item">Shops</a>
            <a href="banners.html" class="nav-item">Banners</a>
            <a href="vouchers.html" class="nav-item">Vouchers</a>
```
to:
```html
            <a href="index.html" class="nav-item">Products</a>
            <a href="categories.html" class="nav-item active">Categories</a>
            <a href="shops.html" class="nav-item">Shops</a>
            <a href="banners.html" class="nav-item">Banners</a>
            <a href="vouchers.html" class="nav-item">Vouchers</a>
            <a href="faqs.html" class="nav-item">FAQs</a>
```

In `admin-panel/shops.html`, change:
```html
            <a href="index.html" class="nav-item">Products</a>
            <a href="categories.html" class="nav-item">Categories</a>
            <a href="shops.html" class="nav-item active">Shops</a>
            <a href="banners.html" class="nav-item">Banners</a>
            <a href="vouchers.html" class="nav-item">Vouchers</a>
```
to:
```html
            <a href="index.html" class="nav-item">Products</a>
            <a href="categories.html" class="nav-item">Categories</a>
            <a href="shops.html" class="nav-item active">Shops</a>
            <a href="banners.html" class="nav-item">Banners</a>
            <a href="vouchers.html" class="nav-item">Vouchers</a>
            <a href="faqs.html" class="nav-item">FAQs</a>
```

In `admin-panel/banners.html`, change:
```html
            <a href="index.html" class="nav-item">Products</a>
            <a href="categories.html" class="nav-item">Categories</a>
            <a href="shops.html" class="nav-item">Shops</a>
            <a href="banners.html" class="nav-item active">Banners</a>
            <a href="vouchers.html" class="nav-item">Vouchers</a>
```
to:
```html
            <a href="index.html" class="nav-item">Products</a>
            <a href="categories.html" class="nav-item">Categories</a>
            <a href="shops.html" class="nav-item">Shops</a>
            <a href="banners.html" class="nav-item active">Banners</a>
            <a href="vouchers.html" class="nav-item">Vouchers</a>
            <a href="faqs.html" class="nav-item">FAQs</a>
```

In `admin-panel/vouchers.html`, change:
```html
            <a href="index.html" class="nav-item">Products</a>
            <a href="categories.html" class="nav-item">Categories</a>
            <a href="shops.html" class="nav-item">Shops</a>
            <a href="banners.html" class="nav-item">Banners</a>
            <a href="vouchers.html" class="nav-item active">Vouchers</a>
```
to:
```html
            <a href="index.html" class="nav-item">Products</a>
            <a href="categories.html" class="nav-item">Categories</a>
            <a href="shops.html" class="nav-item">Shops</a>
            <a href="banners.html" class="nav-item">Banners</a>
            <a href="vouchers.html" class="nav-item active">Vouchers</a>
            <a href="faqs.html" class="nav-item">FAQs</a>
```

- [ ] **Step 2: Create `faqs.html`**

Create `admin-panel/faqs.html`:

```html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FAQs - Admin</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        body {
            display: none;
        }
    </style>
    <script>
        if (!localStorage.getItem('token')) window.location.href = 'login.html';
        else document.addEventListener('DOMContentLoaded', () => document.body.style.display = 'flex');
        window.logout = () => {
            localStorage.removeItem('token');
            localStorage.removeItem('user');
            window.location.href = 'login.html';
        };
    </script>
</head>

<body>
    <div class="sidebar">
        <div class="sidebar-header">
            <div class="logo">🛒 Shop Admin</div>
        </div>
        <nav class="nav-links">
            <a href="index.html" class="nav-item">Products</a>
            <a href="categories.html" class="nav-item">Categories</a>
            <a href="shops.html" class="nav-item">Shops</a>
            <a href="banners.html" class="nav-item">Banners</a>
            <a href="vouchers.html" class="nav-item">Vouchers</a>
            <a href="faqs.html" class="nav-item active">FAQs</a>
        </nav>
    </div>

    <div class="main-content">
        <div class="top-bar">
            <button class="mobile-menu-btn" onclick="toggleSidebar()">☰</button>
            <div class="user-info" id="userInfo"></div>
            <button onclick="logout()" class="logout-btn">Log out</button>
        </div>

        <div class="content-wrapper">
            <div class="card">
                <h2 id="formTitle">Add New FAQ Category</h2>
                <form id="faqForm">
                    <div class="form-grid">
                        <div class="form-group full-width">
                            <label for="title">Category Title</label>
                            <input type="text" id="title" required>
                        </div>
                        <div class="form-group full-width">
                            <label>Questions &amp; Answers</label>
                            <div id="itemsList"></div>
                            <button type="button" class="btn btn-secondary" id="addItemBtn">+ Add Question</button>
                        </div>
                        <div class="form-group full-width" style="text-align: right;">
                            <button type="button" class="btn btn-secondary" id="cancelEdit"
                                style="display:none;">Cancel</button>
                            <button type="submit" class="btn" id="submitBtn">Add Category</button>
                        </div>
                    </div>
                </form>
            </div>

            <div class="card">
                <h2>Existing FAQ Categories</h2>
                <div id="faqList"></div>
            </div>
        </div>
    </div>

    <script src="config.js"></script>
    <script src="faqs.js"></script>
    <script>
        const user = JSON.parse(localStorage.getItem('user'));
        if (user) {
            const initial = user.username.charAt(0).toUpperCase();
            document.getElementById('userInfo').innerHTML = `<div class="avatar">${initial}</div><span>${user.username}</span>`;
        }
    </script>
</body>

</html>
```

- [ ] **Step 3: Create `faqs.js`**

Create `admin-panel/faqs.js`. Note: unlike `categories.js`'s inline `onclick="editCategory('${cat._id}', '${cat.name}', ...)"` string-templating, this uses `addEventListener` with closures capturing the actual object — FAQ answers are long free-text strings that routinely contain quotes and apostrophes, which would break naive attribute-string interpolation. This is a deliberate, justified deviation from the `categories.js` pattern for that reason, not an arbitrary style choice.

```js
const API_URL = CONFIG.API_URL + '/faqs';
const token = localStorage.getItem('token');
const form = document.getElementById('faqForm');
const list = document.getElementById('faqList');
const submitBtn = document.getElementById('submitBtn');
const cancelEditBtn = document.getElementById('cancelEdit');
const formTitle = document.getElementById('formTitle');
const itemsList = document.getElementById('itemsList');
const addItemBtn = document.getElementById('addItemBtn');

let editingId = null;

async function authFetch(url, options = {}) {
    const headers = { ...options.headers, 'Authorization': `Bearer ${token}` };
    const response = await fetch(url, { ...options, headers });
    if (response.status === 401) window.logout();
    return response;
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML.replaceAll('"', '&quot;').replaceAll("'", '&#39;');
}

function addItemRow(question = '', answer = '') {
    const row = document.createElement('div');
    row.className = 'faq-item-row';
    row.style.cssText = 'display:flex; gap:8px; margin-bottom:8px;';
    row.innerHTML = `
        <input type="text" class="item-question" placeholder="Question" value="${escapeHtml(question)}" style="flex:1;">
        <input type="text" class="item-answer" placeholder="Answer" value="${escapeHtml(answer)}" style="flex:2;">
        <button type="button" class="delete-btn remove-item-btn">×</button>
    `;
    row.querySelector('.remove-item-btn').addEventListener('click', () => row.remove());
    itemsList.appendChild(row);
}

addItemBtn.addEventListener('click', () => addItemRow());

async function fetchFaqs() {
    try {
        const res = await authFetch(API_URL);
        const faqs = await res.json();
        renderFaqs(faqs);
    } catch (e) {
        console.error(e);
        list.innerHTML = '<p>Error loading FAQ categories.</p>';
    }
}

function renderFaqs(faqs) {
    list.innerHTML = '';
    faqs.forEach(faq => {
        const div = document.createElement('div');
        div.className = 'product-item';
        div.innerHTML = `
            <div class="product-info">
                <h3>${escapeHtml(faq.title)}</h3>
                <p>${faq.items.length} question${faq.items.length === 1 ? '' : 's'}</p>
            </div>
            <div>
                <button class="btn-edit">Edit</button>
                <button class="delete-btn">Delete</button>
            </div>
        `;
        div.querySelector('.btn-edit').addEventListener('click', () => editFaq(faq));
        div.querySelector('.delete-btn').addEventListener('click', () => deleteFaq(faq._id));
        list.appendChild(div);
    });
}

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const items = Array.from(itemsList.querySelectorAll('.faq-item-row')).map(row => ({
        question: row.querySelector('.item-question').value,
        answer: row.querySelector('.item-answer').value,
    })).filter(item => item.question.trim() && item.answer.trim());

    const data = {
        title: document.getElementById('title').value,
        items,
    };

    try {
        let res;
        if (editingId) {
            res = await authFetch(`${API_URL}/${editingId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
        } else {
            res = await authFetch(API_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
        }

        if (res.ok) {
            resetForm();
            fetchFaqs();
        } else {
            const err = await res.json();
            alert('Error: ' + err.message);
        }
    } catch (e) {
        alert('Request failed');
    }
});

function editFaq(faq) {
    editingId = faq._id;
    document.getElementById('title').value = faq.title;
    itemsList.innerHTML = '';
    faq.items.forEach(item => addItemRow(item.question, item.answer));
    formTitle.textContent = 'Edit FAQ Category';
    submitBtn.textContent = 'Update Category';
    cancelEditBtn.style.display = 'inline-block';
}

async function deleteFaq(id) {
    if (!confirm('Delete this FAQ category and all its questions?')) return;
    try {
        await authFetch(`${API_URL}/${id}`, { method: 'DELETE' });
        fetchFaqs();
    } catch (e) {
        alert('Delete failed');
    }
}

cancelEditBtn.addEventListener('click', resetForm);

function resetForm() {
    form.reset();
    itemsList.innerHTML = '';
    editingId = null;
    formTitle.textContent = 'Add New FAQ Category';
    submitBtn.textContent = 'Add Category';
    cancelEditBtn.style.display = 'none';
    addItemRow();
}

resetForm();
fetchFaqs();
```

- [ ] **Step 4: Manual verification**

Open `admin-panel/faqs.html` in a browser (with the backend running), logged in as an existing admin user. Confirm: the page loads without console errors, "FAQs" is highlighted in the nav, creating a category with 2 questions appears in the list, editing it and changing an answer persists after refresh, and deleting it removes it.

- [ ] **Step 5: Commit**

```bash
git add admin-panel/faqs.html admin-panel/faqs.js admin-panel/index.html admin-panel/categories.html admin-panel/shops.html admin-panel/banners.html admin-panel/vouchers.html
git commit -m "feat(admin): add FAQ category management page"
```

---

### Task 4: Flutter — reshape `FaqCategory`/`FaqItem`, add JSON codecs, category style lookup, and `FaqService`

**Files:**
- Modify: `lib/features/help_support/data/faq_data.dart`
- Create: `lib/features/help_support/presentation/widgets/faq_category_style.dart`
- Create: `lib/features/faq/data/faq_service.dart`
- Test: `test/features/faq/faq_service_test.dart`

**Interfaces:**
- Produces: `class FaqItem` (`question: String`, `answer: String`, `fromJson`/`toJson`), `class FaqCategory` (`title: String`, `items: List<FaqItem>` — **no longer has `icon`/`color` fields**, `fromJson`/`toJson`), `({IconData icon, Color color}) faqCategoryStyle(String title)`, `class FaqFetchResult { List<FaqCategory> categories; bool ok; }`, `class FaqService { Future<FaqFetchResult> fetchFaqs(); }`. Task 5 (`FaqViewModel`) and Task 6 (`DashViewModel`) consume these exact types.
- **Known, deliberate breakage:** this task removes `icon`/`color` from `FaqCategory` and deletes the `const faqData = [...]` constant. `DashViewModel` and `help_support_view.dart` still reference the old `faqData` constant and `cat.icon`/`cat.color` until Tasks 6 and 7 update them — those two files will not compile between this task and Task 7. This mirrors an established pattern in this repo's prior plans (a consumer intentionally left non-compiling until its own task lands). Do not attempt to fix `DashViewModel` or `help_support_view.dart` in this task — that's out of scope here.

- [ ] **Step 1: Reshape `faq_data.dart`**

Replace the entire contents of `lib/features/help_support/data/faq_data.dart` with:

```dart
class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);

  factory FaqItem.fromJson(Map<String, dynamic> json) => FaqItem(
        json['question'] as String,
        json['answer'] as String,
      );

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
}

class FaqCategory {
  final String title;
  final List<FaqItem> items;
  const FaqCategory({required this.title, required this.items});

  factory FaqCategory.fromJson(Map<String, dynamic> json) => FaqCategory(
        title: json['title'] as String,
        items: (json['items'] as List)
            .map((e) => FaqItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
}
```

- [ ] **Step 2: Create the category → icon/color style lookup**

Create `lib/features/help_support/presentation/widgets/faq_category_style.dart`:

```dart
import 'package:flutter/material.dart';

const _fallbackStyle = (icon: Icons.help_outline, color: Color(0xFF607D8B));

const Map<String, ({IconData icon, Color color})> faqCategoryStyles = {
  'Payments': (icon: Icons.payment_outlined, color: Color(0xFF185FA5)),
  'Shopping': (icon: Icons.shopping_bag_outlined, color: Color(0xFF9C27B0)),
  'Calling & Airtime': (icon: Icons.call_outlined, color: Color(0xFF00BCD4)),
  'Wallet': (icon: Icons.account_balance_wallet_outlined, color: Color(0xFF4CAF50)),
  'Utility Bills': (icon: Icons.bolt_outlined, color: Color(0xFFFF9800)),
  'Account & Security': (icon: Icons.security_outlined, color: Color(0xFFE53935)),
  'General': (icon: Icons.help_outline, color: Color(0xFF607D8B)),
};

({IconData icon, Color color}) faqCategoryStyle(String title) =>
    faqCategoryStyles[title] ?? _fallbackStyle;
```

- [ ] **Step 3: Write the failing test for `FaqService`**

Create `test/features/faq/faq_service_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mvvm_sip_demo/features/faq/data/faq_service.dart';

Map<String, dynamic> _categoryJson() => {
      'title': 'Payments',
      'items': [
        {'question': 'Why is my payment pending?', 'answer': 'It can take up to 24 hours.'},
      ],
    };

void main() {
  group('fetchFaqs', () {
    test('parses a successful response into FaqCategory list', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/faqs');
        return http.Response(json.encode([_categoryJson()]), 200);
      });

      final service = FaqService(client: mockClient);
      final result = await service.fetchFaqs();

      expect(result.ok, isTrue);
      expect(result.categories, hasLength(1));
      expect(result.categories.first.title, 'Payments');
      expect(result.categories.first.items.first.question, 'Why is my payment pending?');
    });

    test('returns ok:false with an empty list on a non-200 response', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = FaqService(client: mockClient);

      final result = await service.fetchFaqs();

      expect(result.ok, isFalse);
      expect(result.categories, isEmpty);
    });

    test('returns ok:false with an empty list when the request throws', () async {
      final mockClient = MockClient((request) async => throw Exception('network down'));
      final service = FaqService(client: mockClient);

      final result = await service.fetchFaqs();

      expect(result.ok, isFalse);
      expect(result.categories, isEmpty);
    });
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/features/faq/faq_service_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package ... faq_service.dart` (file doesn't exist yet)

- [ ] **Step 5: Implement `FaqService`**

Create `lib/features/faq/data/faq_service.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../help_support/data/faq_data.dart';

class FaqFetchResult {
  const FaqFetchResult({required this.categories, required this.ok});
  final List<FaqCategory> categories;
  final bool ok;
}

class FaqService {
  FaqService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base = 'https://superapp-diht.onrender.com/api';

  Future<FaqFetchResult> fetchFaqs() async {
    try {
      final uri = Uri.parse('$_base/faqs');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as List;
        final categories = decoded
            .map((e) => FaqCategory.fromJson(e as Map<String, dynamic>))
            .toList();
        return FaqFetchResult(categories: categories, ok: true);
      }
      return const FaqFetchResult(categories: [], ok: false);
    } catch (_) {
      return const FaqFetchResult(categories: [], ok: false);
    }
  }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/faq/faq_service_test.dart`
Expected: `All tests passed!`

- [ ] **Step 7: Verify the scope of this task compiles**

Run: `dart analyze lib/features/help_support/data/faq_data.dart lib/features/help_support/presentation/widgets/faq_category_style.dart lib/features/faq/`
Expected: `No issues found!`

(Do not run a project-wide `dart analyze` yet — `DashViewModel` and `help_support_view.dart` are expected to fail until Tasks 6-7.)

- [ ] **Step 8: Commit**

```bash
git add lib/features/help_support/data/faq_data.dart lib/features/help_support/presentation/widgets/faq_category_style.dart lib/features/faq/data/faq_service.dart test/features/faq/faq_service_test.dart
git commit -m "feat(faq): reshape FaqCategory/FaqItem as pure content, add FaqService"
```

---

### Task 5: Flutter — `FaqViewModel` (cache + background refresh)

**Files:**
- Create: `lib/features/faq/presentation/viewmodels/faq_viewmodel.dart`
- Test: `test/features/faq/faq_viewmodel_test.dart`

**Interfaces:**
- Consumes: `FaqService`, `FaqFetchResult` (Task 4).
- Produces: `class FaqViewModel extends ChangeNotifier` with `FaqViewModel(FaqService service)` constructor, `List<FaqCategory> get categories`, `bool get loading`, `Future<void> loadCached()`, `Future<void> refresh()`. Task 6 (DI wiring, `DashViewModel`) and Task 7 (Help & Support screens) consume this exact API.

- [ ] **Step 1: Write the failing tests**

Create `test/features/faq/faq_viewmodel_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mvvm_sip_demo/features/faq/data/faq_service.dart';
import 'package:mvvm_sip_demo/features/faq/presentation/viewmodels/faq_viewmodel.dart';
import 'package:mvvm_sip_demo/features/help_support/data/faq_data.dart';

class _FakeFaqService implements FaqService {
  _FakeFaqService(this.result);
  final FaqFetchResult result;

  @override
  Future<FaqFetchResult> fetchFaqs() async => result;
}

const _sampleCategory = FaqCategory(
  title: 'Payments',
  items: [FaqItem('Why is my payment pending?', 'Because reasons.')],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts with no categories and not loading', () {
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [], ok: true)));
    expect(vm.categories, isEmpty);
    expect(vm.loading, isFalse);
  });

  test('loadCached does nothing when no cache exists', () async {
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [], ok: true)));
    await vm.loadCached();
    expect(vm.categories, isEmpty);
  });

  test('loadCached populates categories from a prior cache', () async {
    SharedPreferences.setMockInitialValues({
      'faq_cache_v1': json.encode([_sampleCategory.toJson()]),
    });
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [], ok: true)));
    await vm.loadCached();
    expect(vm.categories, hasLength(1));
    expect(vm.categories.first.title, 'Payments');
  });

  test('refresh on success updates categories and writes the cache', () async {
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [_sampleCategory], ok: true)));
    await vm.refresh();

    expect(vm.categories, hasLength(1));
    expect(vm.loading, isFalse);

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('faq_cache_v1');
    expect(cached, isNotNull);
    expect(json.decode(cached!), hasLength(1));
  });

  test('refresh on failure leaves previously-cached categories untouched', () async {
    SharedPreferences.setMockInitialValues({
      'faq_cache_v1': json.encode([_sampleCategory.toJson()]),
    });
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [], ok: false)));
    await vm.loadCached();
    expect(vm.categories, hasLength(1));

    await vm.refresh();
    expect(vm.categories, hasLength(1));
  });

  test('notifies listeners on refresh', () async {
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [_sampleCategory], ok: true)));
    var notified = 0;
    vm.addListener(() => notified++);
    await vm.refresh();
    expect(notified, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/faq/faq_viewmodel_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package ... faq_viewmodel.dart` (file doesn't exist yet)

- [ ] **Step 3: Implement `FaqViewModel`**

Create `lib/features/faq/presentation/viewmodels/faq_viewmodel.dart`:

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../help_support/data/faq_data.dart';
import '../../data/faq_service.dart';

class FaqViewModel extends ChangeNotifier {
  FaqViewModel(this._service);

  final FaqService _service;
  static const _cacheKey = 'faq_cache_v1';

  List<FaqCategory> _categories = [];
  List<FaqCategory> get categories => _categories;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return;
    final decoded = json.decode(cached) as List;
    _categories = decoded
        .map((e) => FaqCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    final result = await _service.fetchFaqs();
    if (result.ok) {
      _categories = result.categories;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        json.encode(_categories.map((c) => c.toJson()).toList()),
      );
    }
    _loading = false;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/faq/faq_viewmodel_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/faq/presentation/viewmodels/faq_viewmodel.dart test/features/faq/faq_viewmodel_test.dart
git commit -m "feat(faq): add FaqViewModel with cache-then-background-refresh"
```

---

### Task 6: Flutter — wire `FaqViewModel` into the app; update `DashViewModel`

**Files:**
- Modify: `lib/core/di/inject.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/home/presentation/views/home_view.dart:52-72`
- Modify: `lib/features/dash/presentation/viewmodels/dash_viewmodel.dart`
- Modify: `test/features/dash/dash_viewmodel_test.dart`

**Interfaces:**
- Consumes: `FaqViewModel` (Task 5).
- Produces: `getIt<FaqViewModel>()` resolvable app-wide; `DashViewModel`'s constructor becomes `DashViewModel(FaqViewModel faqViewModel)`.
- **Resolves the Task 4 breakage** in `DashViewModel` (this task). `help_support_view.dart` remains broken until Task 7 — that's still out of scope here.

- [ ] **Step 1: Register `FaqService`/`FaqViewModel` in the DI container and update `DashViewModel`'s registration**

In `lib/core/di/inject.dart`, add the imports alongside the other feature imports:

```dart
import '../../features/faq/data/faq_service.dart';
import '../../features/faq/presentation/viewmodels/faq_viewmodel.dart';
```

Add the registrations right before the existing `DashViewModel` line, and change that line:

```dart
  getIt.registerLazySingleton(() => FaqService());
  getIt.registerLazySingleton(() => FaqViewModel(getIt<FaqService>()));
  getIt.registerLazySingleton(() => DashViewModel(getIt<FaqViewModel>()));
```

(this replaces the existing `getIt.registerLazySingleton(() => DashViewModel());` line)

- [ ] **Step 2: Expose `FaqViewModel` via `MultiProvider` in `main.dart`**

In `lib/main.dart`, add the import:

```dart
import 'features/faq/presentation/viewmodels/faq_viewmodel.dart';
```

Add to the `MultiProvider.providers` list, right before the existing `DashViewModel` entry:

```dart
        ChangeNotifierProvider(create: (_) => getIt<FaqViewModel>()),
```

- [ ] **Step 3: Trigger the initial load from `home_view.dart`**

In `lib/features/home/presentation/views/home_view.dart`, add the import:

```dart
import 'package:mvvm_sip_demo/features/faq/presentation/viewmodels/faq_viewmodel.dart';
```

In `_HomeViewState.initState()`, change:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<AccountSummaryViewModel>(context, listen: false)
          .loadCurrentUser();

      final creds = await getIt<OtpAuthService>().getStoredCredentials();
```

to:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<AccountSummaryViewModel>(context, listen: false)
          .loadCurrentUser();

      final faqVm = Provider.of<FaqViewModel>(context, listen: false);
      await faqVm.loadCached();
      faqVm.refresh();

      final creds = await getIt<OtpAuthService>().getStoredCredentials();
```

- [ ] **Step 4: Update `DashViewModel` to take `FaqViewModel`**

Replace the entire contents of `lib/features/dash/presentation/viewmodels/dash_viewmodel.dart` with:

```dart
import 'package:flutter/foundation.dart';

import '../../../faq/presentation/viewmodels/faq_viewmodel.dart';

class DashMessage {
  final String text;
  final bool isUser;
  const DashMessage({required this.text, required this.isUser});
}

class _DashReply {
  final String text;
  final bool escalate;
  const _DashReply(this.text, {this.escalate = false});
}

class DashViewModel extends ChangeNotifier {
  DashViewModel(this._faqViewModel);

  final FaqViewModel _faqViewModel;

  final List<DashMessage> _messages = [];
  List<DashMessage> get messages => List.unmodifiable(_messages);

  bool _thinking = false;
  bool get thinking => _thinking;

  bool _nudgeDismissed = false;
  bool get showNudge => !_nudgeDismissed;

  bool _escalate = false;

  void dismissNudge() {
    if (_nudgeDismissed) return;
    _nudgeDismissed = true;
    notifyListeners();
  }

  Future<void> submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _messages.add(DashMessage(text: trimmed, isUser: true));
    _thinking = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    final reply = _matchReply(trimmed);
    _messages.add(DashMessage(text: reply.text, isUser: false));
    _thinking = false;
    _escalate = reply.escalate;
    notifyListeners();
  }

  bool consumeEscalation() {
    final escalate = _escalate;
    _escalate = false;
    return escalate;
  }

  _DashReply _matchReply(String query) {
    final q = query.toLowerCase();

    if (_containsAny(q, const ['human', 'agent', 'person', 'someone'])) {
      return const _DashReply(
        'Connecting you to a human agent over WhatsApp — hang tight.',
        escalate: true,
      );
    }
    if (_containsAny(q, const ['data balance', 'my data', 'data bundle', 'data'])) {
      return const _DashReply(
        'Tap the "Data" chip on your wallet card, or ask me anytime — just say "check my data".',
      );
    }
    if (_containsAny(q, const ['top up', 'topup', 'top-up', 'recharge'])) {
      return const _DashReply(
        'Tap "Top Up" on your wallet card, choose a voucher or payment method, and confirm the amount.',
      );
    }
    if (_containsAny(q, const ['bundle', 'price', 'prices', 'plan'])) {
      return const _DashReply(
        'Bundle prices are on the Data tab — tap "Data — add a bundle" on your wallet card to see current options.',
      );
    }

    for (final cat in _faqViewModel.categories) {
      for (final item in cat.items) {
        final matchesQuestion = item.question.toLowerCase().contains(q);
        final matchesWord = q
            .split(' ')
            .any((w) => w.length > 3 && item.answer.toLowerCase().contains(w));
        if (matchesQuestion || matchesWord) {
          return _DashReply(item.answer);
        }
      }
    }

    return const _DashReply(
      'I was not able to find a specific answer for that. Tap a topic below, or talk to a human.',
    );
  }

  static bool _containsAny(String haystack, List<String> needles) =>
      needles.any(haystack.contains);
}
```

- [ ] **Step 5: Update `DashViewModel`'s tests for the new constructor**

Replace the entire contents of `test/features/dash/dash_viewmodel_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/viewmodels/dash_viewmodel.dart';
import 'package:mvvm_sip_demo/features/faq/data/faq_service.dart';
import 'package:mvvm_sip_demo/features/faq/presentation/viewmodels/faq_viewmodel.dart';
import 'package:mvvm_sip_demo/features/help_support/data/faq_data.dart';

class _FakeFaqService implements FaqService {
  _FakeFaqService(this.categories);
  final List<FaqCategory> categories;

  @override
  Future<FaqFetchResult> fetchFaqs() async =>
      FaqFetchResult(categories: categories, ok: true);
}

const _zesaCategory = FaqCategory(
  title: 'Utility Bills',
  items: [
    FaqItem(
      'How do I pay ZESA?',
      'Tap Bills → Electricity → ZESA, enter your meter number and amount, then confirm payment. The token is delivered by SMS.',
    ),
  ],
);

Future<DashViewModel> _buildViewModel({
  List<FaqCategory> faqCategories = const [],
}) async {
  final faqViewModel = FaqViewModel(_FakeFaqService(faqCategories));
  await faqViewModel.refresh();
  return DashViewModel(faqViewModel);
}

void main() {
  group('DashViewModel', () {
    test('starts with no messages and the nudge shown', () async {
      final vm = await _buildViewModel();
      expect(vm.messages, isEmpty);
      expect(vm.showNudge, isTrue);
      expect(vm.thinking, isFalse);
    });

    test('dismissNudge hides the nudge and notifies listeners', () async {
      final vm = await _buildViewModel();
      var notified = false;
      vm.addListener(() => notified = true);
      vm.dismissNudge();
      expect(vm.showNudge, isFalse);
      expect(notified, isTrue);
    });

    test('submit adds a user message then an assistant reply', () async {
      final vm = await _buildViewModel();
      await vm.submit('Check data balance');
      expect(vm.messages.length, 2);
      expect(vm.messages[0].isUser, isTrue);
      expect(vm.messages[0].text, 'Check data balance');
      expect(vm.messages[1].isUser, isFalse);
      expect(vm.thinking, isFalse);
    });

    test('data balance chip text returns the data-balance reply', () async {
      final vm = await _buildViewModel();
      await vm.submit('Check data balance');
      expect(vm.messages[1].text, contains('Data'));
    });

    test('top up chip text returns the top-up reply', () async {
      final vm = await _buildViewModel();
      await vm.submit('How do I top up?');
      expect(vm.messages[1].text, contains('Top Up'));
    });

    test('bundle prices chip text returns the bundle reply', () async {
      final vm = await _buildViewModel();
      await vm.submit('Bundle prices');
      expect(vm.messages[1].text, contains('Data'));
    });

    test('talk to a human sets the escalation flag and is consumed once', () async {
      final vm = await _buildViewModel();
      await vm.submit('Talk to a human');
      expect(vm.consumeEscalation(), isTrue);
      expect(vm.consumeEscalation(), isFalse);
    });

    test('free text matching a keyword behaves like the matching chip', () async {
      final vm = await _buildViewModel();
      await vm.submit('can you check my data please');
      expect(vm.messages[1].text, contains('Data'));
    });

    test('free text matching an FAQ question returns that answer', () async {
      final vm = await _buildViewModel(faqCategories: const [_zesaCategory]);
      await vm.submit('How do I pay ZESA?');
      expect(vm.messages[1].text, contains('ZESA'));
    });

    test('unmatched free text returns the generic fallback', () async {
      final vm = await _buildViewModel();
      await vm.submit('xyzzy unrelated gibberish');
      expect(vm.messages[1].text, contains('talk to a human'));
      expect(vm.consumeEscalation(), isFalse);
    });

    test('empty submission is a no-op', () async {
      final vm = await _buildViewModel();
      await vm.submit('   ');
      expect(vm.messages, isEmpty);
    });
  });
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/dash/dash_viewmodel_test.dart test/features/faq/`
Expected: `All tests passed!`

(Do NOT run the whole `test/features/dash/` directory here — `dash_bubble_test.dart` and `dash_sheet_test.dart` both transitively import `help_support_view.dart`, which is still broken until Task 7. Batch-compiling them together with the still-broken file can crash the shared Dart compiler process entirely, producing misleading, nondeterministic failure counts that look like flaky test failures but are actually a compile error in an unrelated file. Running just `dash_viewmodel_test.dart` — the only test file this task's `DashViewModel` change affects — avoids this entirely.)

- [ ] **Step 7: Verify the scope of this task compiles**

Run: `dart analyze lib/core/di/inject.dart lib/main.dart lib/features/home/presentation/views/home_view.dart lib/features/dash/ lib/features/faq/`
Expected: `No issues found!`

(`help_support_view.dart` is still expected to fail — Task 7 fixes it.)

- [ ] **Step 8: Commit**

```bash
git add lib/core/di/inject.dart lib/main.dart lib/features/home/presentation/views/home_view.dart lib/features/dash/presentation/viewmodels/dash_viewmodel.dart test/features/dash/dash_viewmodel_test.dart
git commit -m "feat(dash): source keyword-matching FAQ data from FaqViewModel"
```

---

### Task 7: Flutter — migrate Help & Support off the static FAQ data

**Files:**
- Modify: `lib/features/help_support/presentation/views/help_support_view.dart`
- Modify: `test/features/dash/dash_bubble_test.dart`, `test/features/dash/dash_sheet_test.dart` — **plan gap found during Task 7's own project-wide `dart analyze` verification step**: Task 6 changed `DashViewModel`'s constructor to require a `FaqViewModel`, but only updated `dash_viewmodel_test.dart`. These two other test files also construct `DashViewModel()` directly and don't compile until each `DashViewModel()` call becomes `DashViewModel(FaqViewModel(FaqService()))` (with the matching `FaqService`/`FaqViewModel` imports added). This is safe in both files: `FaqService()`'s constructor performs no I/O, and neither test triggers `FaqViewModel.refresh()`/`loadCached()`.

**Interfaces:**
- Consumes: `FaqViewModel` (Task 5), `faqCategoryStyle` (Task 4).
- Produces: Help & Support's FAQ search, FAQ browser, and service-help screens all read live/cached data instead of the (now-deleted) static `faqData` constant. **This task resolves the last remaining Task 4 breakage** — after this task, the whole project compiles again.

- [ ] **Step 1: Add the imports**

In `lib/features/help_support/presentation/views/help_support_view.dart`, add:

```dart
import '../../../faq/presentation/viewmodels/faq_viewmodel.dart';
import '../widgets/faq_category_style.dart';
```

(`package:provider/provider.dart` is already imported in this file.)

- [ ] **Step 2: Replace the FAQ search loop**

Change:

```dart
    final results = <FaqItem>[];
    for (final cat in faqData) {
```

to:

```dart
    final results = <FaqItem>[];
    for (final cat in context.read<FaqViewModel>().categories) {
```

- [ ] **Step 3: Replace the FAQ section's data source**

Change:

```dart
  Widget _buildFaqSection(bool d) {
    return _Section(
      title: 'Frequently Asked Questions',
      isDark: d,
      child: Column(
        children: faqData.map((cat) => _buildFaqCategoryRow(cat, d)).toList(),
      ),
    );
  }
```

to:

```dart
  Widget _buildFaqSection(bool d) {
    return _Section(
      title: 'Frequently Asked Questions',
      isDark: d,
      child: Column(
        children: context
            .watch<FaqViewModel>()
            .categories
            .map((cat) => _buildFaqCategoryRow(cat, d))
            .toList(),
      ),
    );
  }
```

- [ ] **Step 4: Replace icon/color reads in `_buildFaqCategoryRow`**

Change:

```dart
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(cat.icon, color: cat.color, size: 20)),
```

to:

```dart
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: faqCategoryStyle(cat.title).color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(faqCategoryStyle(cat.title).icon, color: faqCategoryStyle(cat.title).color, size: 20)),
```

- [ ] **Step 5: Replace icon/color reads in `_FaqCategoryScreen`**

Change:

```dart
  @override
  Widget build(BuildContext context) {
    final d = isDark;
    return Scaffold(
      backgroundColor: d ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _card(d), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: _text(d), size: 20), onPressed: onBack),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(category.icon, color: category.color, size: 20),
          const SizedBox(width: 8),
          Text(category.title, style: TextStyle(color: _text(d), fontWeight: FontWeight.w600, fontSize: 18)),
        ]),
        centerTitle: true,
      ),
```

to:

```dart
  @override
  Widget build(BuildContext context) {
    final d = isDark;
    final style = faqCategoryStyle(category.title);
    return Scaffold(
      backgroundColor: d ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _card(d), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: _text(d), size: 20), onPressed: onBack),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(style.icon, color: style.color, size: 20),
          const SizedBox(width: 8),
          Text(category.title, style: TextStyle(color: _text(d), fontWeight: FontWeight.w600, fontSize: 18)),
        ]),
        centerTitle: true,
      ),
```

And change:

```dart
              leading: Container(width: 34, height: 34,
                  decoration: BoxDecoration(color: category.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.help_outline, color: category.color, size: 18)),
```

to:

```dart
              leading: Container(width: 34, height: 34,
                  decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.help_outline, color: style.color, size: 18)),
```

- [ ] **Step 6: Replace `_ServiceHelpScreen`'s data source and icon read**

Change:

```dart
  @override
  Widget build(BuildContext context) {
    final d = isDark;
    // Find matching FAQ category
    final faqCat = faqData.where((c) => c.title.toLowerCase().contains(service.name.toLowerCase().split(' ').first)).firstOrNull;
```

to:

```dart
  @override
  Widget build(BuildContext context) {
    final d = isDark;
    // Find matching FAQ category
    final faqCat = context
        .watch<FaqViewModel>()
        .categories
        .where((c) => c.title.toLowerCase().contains(service.name.toLowerCase().split(' ').first))
        .firstOrNull;
```

And change:

```dart
              child: Row(children: [
                Icon(faqCat.icon, color: service.color, size: 22),
```

to:

```dart
              child: Row(children: [
                Icon(faqCategoryStyle(faqCat.title).icon, color: service.color, size: 22),
```

- [ ] **Step 7: Verify the whole project compiles**

Run: `dart analyze`
Expected: `No issues found!` (aside from the same pre-existing, unrelated issues already present before this plan — if any new issues appear in `help_support_view.dart` or the `faq`/`dash` directories, they must be fixed before proceeding).

- [ ] **Step 8: Run the full Dash + FAQ test suites**

Run: `flutter test test/features/dash/ test/features/faq/`
Expected: `All tests passed!`

- [ ] **Step 9: Commit**

```bash
git add lib/features/help_support/presentation/views/help_support_view.dart
git commit -m "feat(help-support): source FAQ browser/search from FaqViewModel"
```

---

### Task 8: Final verification pass

**Files:** none (verification only)

- [ ] **Step 1: Full backend test suite**

Run (from `backend/`): `npx jest`
Expected: all tests pass, including the new `faqs.test.js` and `faq-seed-data.test.js`.

- [ ] **Step 2: Full Flutter static analysis**

Run: `dart analyze`
Expected: `No issues found!` (aside from any pre-existing, unrelated issues that predate this plan).

- [ ] **Step 3: Full Flutter test suite**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: Manual run-through**

With the backend running and a dev database seeded (Task 2, Step 6):
- Open the admin panel, create a new FAQ category with one question.
- Open the app, wait for the background refresh (or pull-to-refresh if the relevant screen supports it), confirm the new category/question appears in Help & Support's FAQ list and that Dash's free-text matching picks it up.
- Edit the question's answer in the admin panel, refresh in-app, confirm the updated text appears.
- Delete the category in the admin panel, refresh in-app, confirm it disappears from both Help & Support and Dash's matching.
- Turn off network on the device/simulator after the first successful load, relaunch the app, confirm cached FAQ content still displays (no blank state).

- [ ] **Step 5: Report results to the user**

Summarize what was verified and flag anything that didn't match the spec before considering the feature done.
