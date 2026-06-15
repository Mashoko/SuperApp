# SuperApp Production Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 18 identified security, persistence, and UI issues to make SuperApp production-ready.

**Architecture:** Backend security is hardened first (helmet, rate-limit, role injection fix), then new MongoDB models and REST routes for Cart/Order/Wishlist/ShippingAddress are added. Flutter's in-memory fake services are replaced with HTTP calls to the real backend. Cart and orders are keyed by `userId` (the gRPC username stored via OtpAuthService) — no backend JWT required from the Flutter client. Fake `AuthService` (SharedPreferences + plaintext passwords) is deleted entirely. UI quick-fixes and new screens complete the work.

**Tech Stack:** Node.js 20, Express 5, Mongoose 8, helmet, express-rate-limit, Flutter 3, Provider 6, GetIt, http package.

---

## File Map

### New Backend Files
- `backend/models/order.model.js` — Order schema
- `backend/models/cart.model.js` — Server-side cart schema
- `backend/models/wishlist.model.js` — Wishlist schema
- `backend/models/shipping_address.model.js` — Shipping address schema

### Modified Backend Files
- `backend/package.json` — add `helmet`, `express-rate-limit`
- `backend/index.js` — security middleware, new routes, fixes

### Deleted Flutter Files
- `lib/services/auth_service.dart`
- `lib/features/auth/presentation/viewmodels/auth_viewmodel.dart`
- `lib/features/auth/presentation/views/signup_view.dart`

### Modified Flutter Files
- `lib/main.dart` — remove AuthViewModel provider
- `lib/core/di/inject.dart` — remove AuthService/AuthViewModel registrations
- `lib/core/routes.dart` — redirect `/signup` to RegistrationView
- `lib/services/shopping_service.dart` — replace in-memory cart/orders with HTTP calls, add search param
- `lib/features/shopping/presentation/viewmodels/shopping_viewmodel.dart` — add searchQuery, async loadCart/orders
- `lib/features/shopping/presentation/views/shopping_view.dart` — wire search, add error state
- `lib/features/shopping/presentation/views/checkout_view.dart` — fix button label, fix Staples
- `lib/features/shopping/presentation/views/order_history_view.dart` — connect to ViewModel
- `lib/features/shopping/presentation/views/widgets/shopping_search_bar.dart` — add onSearch callback
- `lib/features/profile/presentation/views/profile_view.dart` — point Shipping Addresses to real screen

### New Flutter Files
- `lib/features/profile/presentation/views/shipping_addresses_view.dart`
- `lib/services/shipping_address_service.dart`

---

## Task 1: Backend Security — Install Packages & Add Helmet + Rate-Limiting

**Files:**
- Modify: `backend/package.json`
- Modify: `backend/index.js` (lines 1–15)

- [ ] **Step 1: Install security packages**

```bash
cd /home/user/Documents/Calling/SuperApp/backend
npm install helmet express-rate-limit
```

Expected output: added 2 packages

- [ ] **Step 2: Add middleware to index.js — insert after line 6 (`const app = express();`)**

Replace the top of `backend/index.js` (lines 1–10) with:

```javascript
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Security headers
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));

// CORS — restrict to known origins
app.use(cors({
  origin: [
    'http://localhost:3000',
    'http://localhost:8080',
    'https://superapp-diht.onrender.com',
  ],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Rate limiting on auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20,
  message: { message: 'Too many requests, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(express.json());
```

- [ ] **Step 3: Apply rate limiter to auth routes (around line 73 of new file)**

Find `app.post('/api/auth/register'` and change it to:

```javascript
app.post('/api/auth/register', authLimiter, async (req, res) => {
```

Find `app.post('/api/auth/login'` and change it to:

```javascript
app.post('/api/auth/login', authLimiter, async (req, res) => {
```

- [ ] **Step 4: Commit**

```bash
cd /home/user/Documents/Calling/SuperApp
git add backend/package.json backend/package-lock.json backend/index.js
git commit -m "security: add helmet, rate-limit, and restrict CORS origins"
```

---

## Task 2: Backend Security — Fix Role Injection, Upload Auth, Mass-Assignment & usedCount

**Files:**
- Modify: `backend/index.js`

- [ ] **Step 1: Fix register to strip role from request body**

Find the `/api/auth/register` handler body:
```javascript
const { username, password, role } = req.body;
const user = new User({ username, password, role });
```

Replace with:
```javascript
const { username, password } = req.body;
if (!username || !password) {
  return res.status(400).json({ message: 'Username and password are required' });
}
const user = new User({ username, password }); // role defaults to 'staff' in schema
```

- [ ] **Step 2: Add auth middleware to the upload endpoint**

Find:
```javascript
app.post('/api/upload', upload.single('image'), (req, res) => {
```

Replace with:
```javascript
app.post('/api/upload', auth, upload.single('image'), (req, res) => {
```

- [ ] **Step 3: Add Multer file type and size validation**

Find the `const upload = multer({ storage: storage });` line and replace it with:

```javascript
const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
  fileFilter: function (req, file, cb) {
    if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, WEBP and GIF images are allowed'));
    }
  },
});
```

- [ ] **Step 4: Fix mass-assignment on PUT /api/products/:id**

Find:
```javascript
app.put('/api/products/:id', auth, async (req, res) => {
    try {
        const updatedProduct = await Product.findByIdAndUpdate(
            req.params.id,
            req.body,
            { new: true }
        );
        res.json(updatedProduct);
```

Replace with:
```javascript
app.put('/api/products/:id', auth, async (req, res) => {
    try {
        const allowed = ['name', 'description', 'price', 'imageUrl', 'category', 'stock', 'discountPrice', 'isAvailable'];
        const update = {};
        for (const key of allowed) {
            if (req.body[key] !== undefined) update[key] = req.body[key];
        }
        const updatedProduct = await Product.findByIdAndUpdate(
            req.params.id,
            { $set: update },
            { new: true }
        );
        res.json(updatedProduct);
```

- [ ] **Step 5: Increment usedCount when voucher is validated successfully**

Find the line in `/api/validate-voucher` that returns the success response:
```javascript
        res.json({
            valid: true,
            code: voucher.code,
            discount_amount: parseFloat(discountAmount.toFixed(2)),
            message: 'Voucher applied successfully'
        });
```

Replace with:
```javascript
        // Increment usage count
        await Voucher.findByIdAndUpdate(voucher._id, { $inc: { usedCount: 1 } });

        res.json({
            valid: true,
            code: voucher.code,
            discount_amount: parseFloat(discountAmount.toFixed(2)),
            message: 'Voucher applied successfully'
        });
```

- [ ] **Step 6: Commit**

```bash
cd /home/user/Documents/Calling/SuperApp
git add backend/index.js
git commit -m "security: fix role injection, restrict upload, fix mass-assignment, increment usedCount"
```

---

## Task 3: Backend — Cart Model & API

**Files:**
- Create: `backend/models/cart.model.js`
- Modify: `backend/index.js`

- [ ] **Step 1: Create cart model**

Create `backend/models/cart.model.js`:

```javascript
const mongoose = require('mongoose');

const cartItemSchema = new mongoose.Schema({
  productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
  quantity: { type: Number, required: true, min: 1, default: 1 },
});

const cartSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, unique: true, index: true },
    items: [cartItemSchema],
  },
  { timestamps: true }
);

module.exports = mongoose.model('Cart', cartSchema);
```

- [ ] **Step 2: Add cart routes to index.js — add before `app.listen`**

Add this block to `backend/index.js` before the final `app.listen` call:

```javascript
// --- Cart Routes ---
const Cart = require('./models/cart.model');

// Helper: build the cart response object (populates product details)
async function buildCartResponse(cart) {
  const populatedItems = await Promise.all(
    (cart ? cart.items : []).map(async (item) => {
      const product = await Product.findById(item.productId);
      if (!product || product.isDeleted) return null;
      return {
        product: {
          _id: product._id,
          product_id: product._id,
          name: product.name,
          price: product.price,
          imageUrl: product.imageUrl,
          image_url: product.imageUrl,
          category: product.category,
          stock: product.stock,
          description: product.description,
          unit: 'kg',
        },
        quantity: item.quantity,
        total: product.price * item.quantity,
      };
    })
  );

  const filteredItems = populatedItems.filter((i) => i !== null);
  const total = filteredItems.reduce((sum, i) => sum + i.total, 0);

  return {
    user_id: cart ? cart.userId : '',
    items: filteredItems,
    total: parseFloat(total.toFixed(2)),
    item_count: filteredItems.length,
  };
}

// GET /api/cart?userId=<username>
app.get('/api/cart', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ message: 'userId required' });
    const cart = await Cart.findOne({ userId });
    res.json(await buildCartResponse(cart));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/cart/add  { userId, productId, quantity }
app.post('/api/cart/add', async (req, res) => {
  try {
    const { userId, productId, quantity = 1 } = req.body;
    if (!userId || !productId) return res.status(400).json({ message: 'userId and productId required' });

    const product = await Product.findById(productId);
    if (!product || product.isDeleted) return res.status(404).json({ message: 'Product not found' });

    let cart = await Cart.findOne({ userId });
    if (!cart) cart = new Cart({ userId, items: [] });

    const existingIdx = cart.items.findIndex((i) => i.productId.toString() === productId);
    if (existingIdx !== -1) {
      cart.items[existingIdx].quantity += quantity;
    } else {
      cart.items.push({ productId, quantity });
    }

    await cart.save();
    res.json(await buildCartResponse(cart));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// PUT /api/cart/update  { userId, productId, quantity }
app.put('/api/cart/update', async (req, res) => {
  try {
    const { userId, productId, quantity } = req.body;
    if (!userId || !productId || quantity === undefined) {
      return res.status(400).json({ message: 'userId, productId, and quantity required' });
    }

    const cart = await Cart.findOne({ userId });
    if (!cart) return res.status(404).json({ message: 'Cart not found' });

    const idx = cart.items.findIndex((i) => i.productId.toString() === productId);
    if (idx === -1) return res.status(404).json({ message: 'Item not in cart' });

    if (quantity <= 0) {
      cart.items.splice(idx, 1);
    } else {
      cart.items[idx].quantity = quantity;
    }

    await cart.save();
    res.json(await buildCartResponse(cart));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE /api/cart/remove  { userId, productId }
app.delete('/api/cart/remove', async (req, res) => {
  try {
    const { userId, productId } = req.body;
    if (!userId || !productId) return res.status(400).json({ message: 'userId and productId required' });

    const cart = await Cart.findOne({ userId });
    if (!cart) return res.status(404).json({ message: 'Cart not found' });

    cart.items = cart.items.filter((i) => i.productId.toString() !== productId);
    await cart.save();
    res.json(await buildCartResponse(cart));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE /api/cart/clear  { userId }
app.delete('/api/cart/clear', async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ message: 'userId required' });
    await Cart.findOneAndUpdate({ userId }, { items: [] });
    res.json({ message: 'Cart cleared' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});
```

- [ ] **Step 3: Commit**

```bash
cd /home/user/Documents/Calling/SuperApp
git add backend/models/cart.model.js backend/index.js
git commit -m "feat(backend): add server-side cart model and REST API"
```

---

## Task 4: Backend — Order Model & API

**Files:**
- Create: `backend/models/order.model.js`
- Modify: `backend/index.js`

- [ ] **Step 1: Create order model**

Create `backend/models/order.model.js`:

```javascript
const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema({
  product: { type: Object, required: true }, // Denormalized product snapshot
  quantity: { type: Number, required: true },
  total: { type: Number, required: true },
});

const orderSchema = new mongoose.Schema(
  {
    order_id: { type: String, required: true, unique: true },
    user_id: { type: String, required: true, index: true },
    items: [orderItemSchema],
    shipping_address: { type: String, default: '' },
    status: {
      type: String,
      enum: ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'],
      default: 'confirmed',
    },
    transaction_id: { type: String, default: null },
    payment_status: { type: String, default: 'pending' },
    total_amount: { type: Number, required: true },
    discount_code: { type: String, default: null },
    discount_amount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

// Virtual for created_at compatibility
orderSchema.virtual('created_at').get(function () {
  return this.createdAt;
});

orderSchema.set('toJSON', { virtuals: true });

module.exports = mongoose.model('Order', orderSchema);
```

- [ ] **Step 2: Add order routes to index.js — add before `app.listen`**

```javascript
// --- Order Routes ---
const Order = require('./models/order.model');

// POST /api/orders  { userId, items, shippingAddress, transactionId, paymentStatus, total, discountCode, discountAmount }
app.post('/api/orders', async (req, res) => {
  try {
    const {
      userId,
      items,
      shippingAddress,
      transactionId,
      paymentStatus = 'pending',
      total,
      discountCode,
      discountAmount = 0,
    } = req.body;

    if (!userId || !items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'userId and items are required' });
    }

    const orderId = `order_${Date.now()}_${userId}`;

    const order = new Order({
      order_id: orderId,
      user_id: userId,
      items: items,
      shipping_address: shippingAddress || '',
      transaction_id: transactionId || null,
      payment_status: paymentStatus,
      total_amount: total || 0,
      discount_code: discountCode || null,
      discount_amount: discountAmount,
      status: 'confirmed',
    });

    const savedOrder = await order.save();

    // Clear the user's cart after successful order
    await Cart.findOneAndUpdate({ userId }, { items: [] });

    res.status(201).json(savedOrder);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/orders?userId=<username>
app.get('/api/orders', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ message: 'userId required' });
    const orders = await Order.find({ user_id: userId }).sort({ createdAt: -1 });
    res.json(orders);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// PATCH /api/orders/:id/status  (admin)
app.patch('/api/orders/:id/status', auth, async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }
    const order = await Order.findByIdAndUpdate(req.params.id, { status }, { new: true });
    res.json(order);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});
```

- [ ] **Step 3: Commit**

```bash
cd /home/user/Documents/Calling/SuperApp
git add backend/models/order.model.js backend/index.js
git commit -m "feat(backend): add order model and REST API with cart auto-clear on order"
```

---

## Task 5: Backend — Wishlist, Shipping Address Models & Payment Proxy

**Files:**
- Create: `backend/models/wishlist.model.js`
- Create: `backend/models/shipping_address.model.js`
- Modify: `backend/index.js`

- [ ] **Step 1: Create wishlist model**

Create `backend/models/wishlist.model.js`:

```javascript
const mongoose = require('mongoose');

const wishlistSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, unique: true, index: true },
    productIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Product' }],
  },
  { timestamps: true }
);

module.exports = mongoose.model('Wishlist', wishlistSchema);
```

- [ ] **Step 2: Create shipping address model**

Create `backend/models/shipping_address.model.js`:

```javascript
const mongoose = require('mongoose');

const shippingAddressSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    label: { type: String, required: true },   // e.g. "Home", "Office"
    address: { type: String, required: true },
    city: { type: String, default: '' },
    phone: { type: String, default: '' },
    isDefault: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model('ShippingAddress', shippingAddressSchema);
```

- [ ] **Step 3: Add wishlist + shipping address routes to index.js — add before `app.listen`**

```javascript
// --- Wishlist Routes ---
const Wishlist = require('./models/wishlist.model');

// GET /api/wishlist?userId=<username>
app.get('/api/wishlist', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ message: 'userId required' });
    const wishlist = await Wishlist.findOne({ userId });
    const productIds = wishlist ? wishlist.productIds.map((id) => id.toString()) : [];
    const products = await Product.find({ _id: { $in: productIds }, isDeleted: false });
    res.json(products);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/wishlist/add  { userId, productId }
app.post('/api/wishlist/add', async (req, res) => {
  try {
    const { userId, productId } = req.body;
    if (!userId || !productId) return res.status(400).json({ message: 'userId and productId required' });
    await Wishlist.findOneAndUpdate(
      { userId },
      { $addToSet: { productIds: productId } },
      { upsert: true, new: true }
    );
    res.json({ message: 'Added to wishlist' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE /api/wishlist/remove/:productId?userId=<username>
app.delete('/api/wishlist/remove/:productId', async (req, res) => {
  try {
    const { userId } = req.query;
    const { productId } = req.params;
    if (!userId) return res.status(400).json({ message: 'userId required' });
    await Wishlist.findOneAndUpdate({ userId }, { $pull: { productIds: productId } });
    res.json({ message: 'Removed from wishlist' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// --- Shipping Address Routes ---
const ShippingAddress = require('./models/shipping_address.model');

// GET /api/shipping-addresses?userId=<username>
app.get('/api/shipping-addresses', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ message: 'userId required' });
    const addresses = await ShippingAddress.find({ userId }).sort({ isDefault: -1, createdAt: -1 });
    res.json(addresses);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/shipping-addresses  { userId, label, address, city, phone, isDefault }
app.post('/api/shipping-addresses', async (req, res) => {
  try {
    const { userId, label, address, city, phone, isDefault } = req.body;
    if (!userId || !label || !address) {
      return res.status(400).json({ message: 'userId, label, and address are required' });
    }
    if (isDefault) {
      await ShippingAddress.updateMany({ userId }, { isDefault: false });
    }
    const addr = new ShippingAddress({ userId, label, address, city, phone, isDefault: isDefault || false });
    await addr.save();
    res.status(201).json(addr);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE /api/shipping-addresses/:id?userId=<username>
app.delete('/api/shipping-addresses/:id', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ message: 'userId required' });
    await ShippingAddress.findOneAndDelete({ _id: req.params.id, userId });
    res.json({ message: 'Address deleted' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// --- Payment Proxy ---
// POST /api/payments/africom/superapp-pay
// Proxies to Africom SuperApp Pay (or returns configured test response)
app.post('/api/payments/africom/superapp-pay', async (req, res) => {
  try {
    const { amount, currency, reference, user_id, channel } = req.body;
    if (!amount || !currency || !reference || !user_id) {
      return res.status(400).json({ message: 'amount, currency, reference, and user_id are required' });
    }

    // ── Africom integration placeholder ──────────────────────────────────────
    // When you have your Africom credentials, replace this section with a real
    // HTTP call to their API (e.g. using node-fetch or axios).
    //
    // Example:
    //   const africomRes = await fetch('https://api.africom.co.zw/pay', {
    //     method: 'POST',
    //     headers: { 'X-Integration-Id': process.env.AFRICOM_INTEGRATION_ID,
    //                 'X-Integration-Key': process.env.AFRICOM_INTEGRATION_KEY },
    //     body: JSON.stringify({ amount, currency, reference, user_id, channel }),
    //   });
    //   const data = await africomRes.json();
    //   return res.status(africomRes.status).json(data);
    //
    // Until then, return a test success so the Flutter checkout flow completes.
    // ─────────────────────────────────────────────────────────────────────────

    return res.json({
      status: 'success',
      paid: true,
      transaction_id: `TXN-${Date.now()}`,
      message: 'Payment processed successfully',
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});
```

- [ ] **Step 4: Also add search support to GET /api/products**

Find in `backend/index.js`:
```javascript
        const filter = { isDeleted: false };
        if (req.query.category && req.query.category !== 'All') {
            filter.category = req.query.category;
        }
```

Replace with:
```javascript
        const filter = { isDeleted: false };
        if (req.query.category && req.query.category !== 'All') {
            filter.category = req.query.category;
        }
        if (req.query.search && req.query.search.trim() !== '') {
            const searchRegex = new RegExp(req.query.search.trim(), 'i');
            filter.$or = [{ name: searchRegex }, { description: searchRegex }];
        }
```

- [ ] **Step 5: Commit**

```bash
cd /home/user/Documents/Calling/SuperApp
git add backend/models/wishlist.model.js backend/models/shipping_address.model.js backend/index.js
git commit -m "feat(backend): add wishlist, shipping address, payment proxy, and product search"
```

---

## Task 6: Flutter — Remove Fake AuthService

**Files:**
- Delete: `lib/services/auth_service.dart`
- Delete: `lib/features/auth/presentation/viewmodels/auth_viewmodel.dart`
- Delete: `lib/features/auth/presentation/views/signup_view.dart`
- Modify: `lib/main.dart`
- Modify: `lib/core/di/inject.dart`
- Modify: `lib/core/routes.dart`
- Modify: `lib/features/calling/presentation/views/call_history_view.dart`

- [ ] **Step 1: Delete the three fake auth files**

```bash
rm /home/user/Documents/Calling/SuperApp/lib/services/auth_service.dart
rm /home/user/Documents/Calling/SuperApp/lib/features/auth/presentation/viewmodels/auth_viewmodel.dart
rm /home/user/Documents/Calling/SuperApp/lib/features/auth/presentation/views/signup_view.dart
```

- [ ] **Step 2: Remove AuthViewModel from main.dart**

In `lib/main.dart`, remove:
```dart
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';
```

And remove from the `providers` list:
```dart
        ChangeNotifierProvider(create: (_) => getIt<AuthViewModel>()),
```

- [ ] **Step 3: Remove registrations from inject.dart**

In `lib/core/di/inject.dart`, remove these two import lines:
```dart
import '../../services/auth_service.dart'; // New AuthService
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
```

And remove these two registration lines:
```dart
  getIt.registerLazySingleton<AuthService>(() => AuthService()); // New AppAuthService
  getIt.registerFactory(() => AuthViewModel(getIt())); // Inject AuthService
```

- [ ] **Step 4: Fix routes.dart — redirect /signup to RegistrationView**

In `lib/core/routes.dart`, remove:
```dart
import 'package:mvvm_sip_demo/features/auth/presentation/views/signup_view.dart';
```

Change:
```dart
        signup: (context) => SignupView(),
```
to:
```dart
        signup: (context) => RegistrationView(),
```

- [ ] **Step 5: Remove unused import from call_history_view.dart**

In `lib/features/calling/presentation/views/call_history_view.dart`, remove:
```dart
import 'package:mvvm_sip_demo/features/auth/presentation/viewmodels/auth_viewmodel.dart';
```

- [ ] **Step 6: Verify the app compiles**

```bash
cd /home/user/Documents/Calling/SuperApp
flutter analyze lib/main.dart lib/core/routes.dart lib/core/di/inject.dart lib/features/calling/presentation/views/call_history_view.dart 2>&1 | grep -E "error|warning" | head -20
```

Expected: zero errors (warnings are OK).

- [ ] **Step 7: Commit**

```bash
cd /home/user/Documents/Calling/SuperApp
git add -A
git commit -m "refactor: delete fake AuthService and AuthViewModel, redirect signup to OTP registration"
```

---

## Task 7: Flutter — Connect Cart & Orders to Backend

**Files:**
- Modify: `lib/services/shopping_service.dart`
- Modify: `lib/features/shopping/presentation/viewmodels/shopping_viewmodel.dart`
- Modify: `lib/features/shopping/presentation/views/order_history_view.dart`
- Modify: `lib/features/shopping/presentation/views/checkout_view.dart` (button label + Staples fix)

- [ ] **Step 1: Replace in-memory cart/order logic in ShoppingService**

Replace the entire `lib/services/shopping_service.dart` with:

```dart
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/models/shopping/cart_item.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/order_status.dart';
import 'package:mvvm_sip_demo/models/shopping/banner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ShoppingService {
  static const String _base = 'https://superapp-diht.onrender.com/api';

  // ── Product catalog (in-memory cache for browse) ──────────────────────────
  final Map<String, Product> _products = {};

  ShoppingService();

  Future<({List<Product> products, int totalPages})> fetchProducts({
    int page = 1,
    int limit = 10,
    String? category,
    String? search,
  }) async {
    try {
      final params = <String, String>{
        'page': '$page',
        'limit': '$limit',
      };
      if (category != null && category != 'All') params['category'] = category;
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

      final uri = Uri.parse('$_base/products').replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        List<dynamic> productList;
        int totalPages = 1;

        if (decoded is List) {
          productList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          productList = decoded['products'] ?? [];
          totalPages = decoded['totalPages'] ?? 1;
        } else {
          return (products: <Product>[], totalPages: 0);
        }

        final List<Product> newProducts = [];
        for (final item in productList) {
          final product = Product.fromJson(item);
          _products[product.productId] = product;
          newProducts.add(product);
        }
        return (products: newProducts, totalPages: totalPages);
      } else {
        return (products: <Product>[], totalPages: 0);
      }
    } catch (e) {
      return (products: <Product>[], totalPages: 0);
    }
  }

  Future<List<String>> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_base/categories?hasProducts=true'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => j['name'].toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Banner>> fetchBanners() async {
    try {
      final response = await http.get(Uri.parse('$_base/banners'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Banner.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Product? getProduct(String productId) => _products[productId];

  // ── Cart (server-side) ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchCart(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_base/cart?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<Map<String, dynamic>> addToCart(String userId, String productId,
      {int quantity = 1}) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/cart/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<Map<String, dynamic>> updateCartQuantity(
      String userId, String productId, int quantity) async {
    if (quantity <= 0) return removeFromCart(userId, productId);
    try {
      final response = await http.put(
        Uri.parse('$_base/cart/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<Map<String, dynamic>> removeFromCart(
      String userId, String productId) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$_base/cart/remove'));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'userId': userId, 'productId': productId});
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<void> clearCart(String userId) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$_base/cart/clear'));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'userId': userId});
      final streamedResponse = await request.send();
      await http.Response.fromStream(streamedResponse);
    } catch (_) {}
  }

  Map<String, dynamic> _emptyCart(String userId) => {
        'user_id': userId,
        'items': <dynamic>[],
        'total': 0.0,
        'item_count': 0,
      };

  // ── Orders (server-side) ──────────────────────────────────────────────────

  Future<Order?> placeOrder(
    String userId,
    String shippingAddress, {
    String? transactionId,
    String paymentStatus = 'pending',
    double discountAmount = 0.0,
    String? discountCode,
    required Map<String, dynamic> cartSnapshot,
  }) async {
    try {
      final cartItems = cartSnapshot['items'] as List<dynamic>? ?? [];
      final total = (cartSnapshot['total'] as num?)?.toDouble() ?? 0.0;

      final itemsPayload = cartItems.map((item) {
        final productData = item['product'] as Map<String, dynamic>;
        final quantity = item['quantity'] as int;
        final itemTotal = (item['total'] as num?)?.toDouble() ?? 0.0;
        return {
          'product': productData,
          'quantity': quantity,
          'total': itemTotal,
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$_base/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'items': itemsPayload,
          'shippingAddress': shippingAddress,
          'transactionId': transactionId,
          'paymentStatus': paymentStatus,
          'total': total - discountAmount,
          'discountCode': discountCode,
          'discountAmount': discountAmount,
        }),
      );

      if (response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return Order.fromJson(decoded);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Order>> fetchOrders(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_base/orders?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Order.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Voucher ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> validateVoucher(
      String code, double total) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/validate-voucher'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': code, 'cart_total': total}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Invalid voucher');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
```

- [ ] **Step 2: Update ShoppingViewModel to use async backend cart/orders**

Replace the entire `lib/features/shopping/presentation/viewmodels/shopping_viewmodel.dart` with:

```dart
import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/banner.dart';
import 'package:mvvm_sip_demo/services/shopping_service.dart';

class ShoppingViewModel extends ChangeNotifier {
  final ShoppingService _service;

  ShoppingViewModel(this._service);

  List<Product> _products = [];
  Map<String, dynamic> _cart = {};
  List<Order> _orders = [];
  List<Banner> _banners = [];
  List<String> _categories = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  String? _errorMessage;

  String _userId = '';
  String _selectedCategory = 'All';
  String _searchQuery = '';

  int _page = 1;
  int _totalPages = 1;

  String? _discountCode;
  double _discountAmount = 0.0;
  bool _isCheckingVoucher = false;

  List<String> _recentSearches = [];

  // ── Getters ──────────────────────────────────────────────────────────────

  List<Product> get products => _products;
  Map<String, dynamic> get cart => _cart;
  List<Order> get orders => _orders;
  List<Banner> get banners => _banners;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isMoreLoading => _isMoreLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  String get userId => _userId;

  String? get discountCode => _discountCode;
  double get discountAmount => _discountAmount;
  bool get isCheckingVoucher => _isCheckingVoucher;
  double get total =>
      ((_cart['total'] ?? 0.0) as num).toDouble() - _discountAmount;

  List<String> get recentSearches => _recentSearches;

  // ── Private helpers ───────────────────────────────────────────────────────

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setMoreLoading(bool v) { _isMoreLoading = v; notifyListeners(); }
  void _setError(String? e) { _errorMessage = e; notifyListeners(); }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> loadProducts({String? category, String? search}) async {
    try {
      _setLoading(true);
      _setError(null);
      _page = 1;
      _totalPages = 1;

      await Future.wait([loadCategories(), loadBanners()]);

      final cat = category ?? _selectedCategory;
      final q = search ?? _searchQuery;

      final result = await _service.fetchProducts(
        page: 1,
        category: cat,
        search: q.isEmpty ? null : q,
      );

      _products = result.products;
      _totalPages = result.totalPages;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load products. Check your connection and try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMoreProducts() async {
    if (_isLoading || _isMoreLoading || _page >= _totalPages) return;
    try {
      _setMoreLoading(true);
      _page++;
      final result = await _service.fetchProducts(
        page: _page,
        category: _selectedCategory,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      _products.addAll(result.products);
      notifyListeners();
    } catch (e) {
      _page--;
      _setError('Failed to load more products.');
    } finally {
      _setMoreLoading(false);
    }
  }

  Future<void> loadBanners() async {
    try {
      _banners = await _service.fetchBanners();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadCategories() async {
    try {
      final loaded = await _service.fetchCategories();
      _categories = loaded.isNotEmpty ? ['All', ...loaded] : ['All'];
      if (!_categories.contains(_selectedCategory)) _selectedCategory = 'All';
      notifyListeners();
    } catch (_) {}
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _searchQuery = '';
    notifyListeners();
    loadProducts(category: category);
  }

  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    _selectedCategory = 'All';
    notifyListeners();
    await loadProducts(search: query);
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
    loadProducts();
  }

  void addRecentSearch(String term) {
    if (term.isEmpty) return;
    _recentSearches.remove(term);
    _recentSearches.insert(0, term);
    if (_recentSearches.length > 10) _recentSearches = _recentSearches.sublist(0, 10);
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }

  // ── Cart ──────────────────────────────────────────────────────────────────

  Future<void> loadCart(String userId) async {
    try {
      _userId = userId;
      _cart = await _service.fetchCart(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load cart.');
    }
  }

  Future<void> addToCart(String userId, String productId,
      {int quantity = 1}) async {
    try {
      _userId = userId;
      _setError(null);
      _cart = await _service.addToCart(userId, productId, quantity: quantity);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add to cart.');
    }
  }

  Future<void> updateCartQuantity(
      String userId, String productId, int quantity) async {
    try {
      _setError(null);
      _cart = await _service.updateCartQuantity(userId, productId, quantity);
      notifyListeners();
    } catch (e) {
      _setError('Failed to update cart.');
    }
  }

  Future<void> removeFromCart(String userId, String productId) async {
    try {
      _setError(null);
      _cart = await _service.removeFromCart(userId, productId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove from cart.');
    }
  }

  void clearCart() {
    _cart = {};
    _discountCode = null;
    _discountAmount = 0.0;
    notifyListeners();
  }

  int getProductQuantity(String productId) {
    if (_cart['items'] == null) return 0;
    final items = _cart['items'] as List<dynamic>;
    try {
      final item = items.firstWhere(
        (i) => i['product']?['_id']?.toString() == productId ||
               i['product']?['product_id']?.toString() == productId,
        orElse: () => null,
      );
      return (item != null) ? (item['quantity'] as int? ?? 0) : 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Voucher ───────────────────────────────────────────────────────────────

  Future<void> applyDiscount(String code) async {
    try {
      _isCheckingVoucher = true;
      _setError(null);
      notifyListeners();

      final cartTotal = (_cart['total'] as num?)?.toDouble() ?? 0.0;
      final result = await _service.validateVoucher(code, cartTotal);

      if (result['valid'] == true) {
        _discountCode = result['code'];
        _discountAmount = (result['discount_amount'] as num).toDouble();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        _errorMessage = null;
        notifyListeners();
      });
    } finally {
      _isCheckingVoucher = false;
      notifyListeners();
    }
  }

  void removeDiscount() {
    _discountCode = null;
    _discountAmount = 0.0;
    notifyListeners();
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  Future<bool> placeOrder(
    String userId,
    String shippingAddress, {
    String? transactionId,
    String paymentStatus = 'pending',
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final order = await _service.placeOrder(
        userId,
        shippingAddress,
        transactionId: transactionId,
        paymentStatus: paymentStatus,
        discountAmount: _discountAmount,
        discountCode: _discountCode,
        cartSnapshot: Map<String, dynamic>.from(_cart),
      );

      if (order != null) {
        clearCart();
        await _service.clearCart(userId);
        await loadOrders(userId: userId);
        return true;
      } else {
        _setError('Failed to place order. Please try again.');
        return false;
      }
    } catch (e) {
      _setError('Failed to place order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadOrders({String? userId}) async {
    try {
      _setLoading(true);
      _setError(null);
      final uid = userId ?? _userId;
      if (uid.isEmpty) return;
      _orders = await _service.fetchOrders(uid);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load orders.');
    } finally {
      _setLoading(false);
    }
  }
}
```

- [ ] **Step 3: Fix the two UI hardcodes in checkout_view.dart**

In `lib/features/shopping/presentation/views/checkout_view.dart`:

**Fix 1 — "Staples" hardcoded category label (around line 472):**

Find:
```dart
                    Text('Staples',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
```

Replace with:
```dart
                    Text(product.category.isNotEmpty ? product.category : 'General',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
```

**Fix 2 — Checkout button label (around line 395):**

Find:
```dart
                    child: const Text(
                      'Pay with Paynow',
```

Replace with:
```dart
                    child: const Text(
                      'Proceed to Pay',
```

- [ ] **Step 4: Connect OrderHistoryView to ViewModel**

Replace `lib/features/shopping/presentation/views/order_history_view.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/order_status.dart';

class OrderHistoryView extends StatefulWidget {
  const OrderHistoryView({super.key});

  @override
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final creds = await getIt<OtpAuthService>().getStoredCredentials();
      final userId = creds?['username'] ?? '';
      if (!mounted) return;
      Provider.of<ShoppingViewModel>(context, listen: false)
          .loadOrders(userId: userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Consumer<ShoppingViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(vm.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final creds =
                          await getIt<OtpAuthService>().getStoredCredentials();
                      final userId = creds?['username'] ?? '';
                      if (!context.mounted) return;
                      Provider.of<ShoppingViewModel>(context, listen: false)
                          .loadOrders(userId: userId);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (vm.orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No orders yet',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Your order history will appear here.',
                      style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.orders.length,
            itemBuilder: (context, index) {
              final order = vm.orders[index];
              return _OrderCard(order: order);
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered: return Colors.green;
      case OrderStatus.cancelled: return Colors.red;
      case OrderStatus.shipped: return Colors.blue;
      default: return WunzaColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    final date = DateFormat('MMM d, yyyy').format(order.createdAt);
    final itemCount = order.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WunzaColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.orderId.split('_').last.substring(0, 6).toUpperCase()}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status.value[0].toUpperCase() +
                      order.status.value.substring(1),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$itemCount ${itemCount == 1 ? 'Item' : 'Items'} · \$${order.totalAmount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Placed on $date',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: WunzaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Verify compile**

```bash
cd /home/user/Documents/Calling/SuperApp
flutter analyze lib/services/shopping_service.dart lib/features/shopping/presentation/viewmodels/shopping_viewmodel.dart lib/features/shopping/presentation/views/order_history_view.dart lib/features/shopping/presentation/views/checkout_view.dart 2>&1 | grep -E "^  error" | head -20
```

Expected: zero errors.

- [ ] **Step 6: Commit**

```bash
cd /home/user/Documents/Calling/SuperApp
git add lib/services/shopping_service.dart \
        lib/features/shopping/presentation/viewmodels/shopping_viewmodel.dart \
        lib/features/shopping/presentation/views/order_history_view.dart \
        lib/features/shopping/presentation/views/checkout_view.dart
git commit -m "feat(flutter): connect cart and orders to backend; fix Staples label and button text"
```

---

## Task 8: Flutter — Wire Product Search Bar

**Files:**
- Modify: `lib/features/shopping/presentation/views/widgets/shopping_search_bar.dart`
- Modify: `lib/features/shopping/presentation/views/shopping_view.dart`

- [ ] **Step 1: Add onSearch callback to ShoppingSearchBar**

Replace `lib/features/shopping/presentation/views/widgets/shopping_search_bar.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class ShoppingSearchBar extends StatefulWidget {
  final VoidCallback? onCartPressed;
  final VoidCallback? onBackPressed;
  final int cartItemCount;
  final ValueChanged<String>? onSearch;

  const ShoppingSearchBar({
    super.key,
    this.onCartPressed,
    this.onBackPressed,
    this.cartItemCount = 0,
    this.onSearch,
  });

  @override
  State<ShoppingSearchBar> createState() => _ShoppingSearchBarState();
}

class _ShoppingSearchBarState extends State<ShoppingSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          if (widget.onBackPressed != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: widget.onBackPressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: WunzaColors.premiumText,
            ),
          if (widget.onBackPressed != null) const SizedBox(width: 12),

          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: WunzaColors.premiumSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  widget.onSearch?.call(trimmed);
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search product',
                  hintStyle:
                      const TextStyle(color: WunzaColors.textSecondary),
                  prefixIcon: const Icon(Icons.search,
                      color: WunzaColors.textSecondary),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      return value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: WunzaColors.textSecondary),
                              onPressed: () {
                                _controller.clear();
                                widget.onSearch?.call('');
                              },
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          if (widget.onCartPressed != null) ...[
            const SizedBox(width: 12),
            Stack(
              children: [
                IconButton(
                  onPressed: widget.onCartPressed,
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: WunzaColors.premiumText),
                ),
                if (widget.cartItemCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                          minWidth: 16, minHeight: 16),
                      child: Text(
                        '${widget.cartItemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Wire onSearch in ShoppingView**

In `lib/features/shopping/presentation/views/shopping_view.dart`, find the `ShoppingSearchBar(` widget and add the `onSearch` callback:

Find:
```dart
                    return ShoppingSearchBar(
                      onBackPressed:
                          widget.onBack ?? () { Future.delayed(Duration.zero, () { if (context.mounted) Navigator.pop(context); }); },
                      onCartPressed: () =>
                          Navigator.pushNamed(context, Routes.cart),
                      cartItemCount: itemCount,
                    );
```

Replace with:
```dart
                    return ShoppingSearchBar(
                      onBackPressed:
                          widget.onBack ?? () { Future.delayed(Duration.zero, () { if (context.mounted) Navigator.pop(context); }); },
                      onCartPressed: () =>
                          Navigator.pushNamed(context, Routes.cart),
                      cartItemCount: itemCount,
                      onSearch: (query) {
                        final vm = context.read<ShoppingViewModel>();
                        if (query.isEmpty) {
                          vm.clearSearch();
                        } else {
                          vm.addRecentSearch(query);
                          vm.searchProducts(query);
                        }
                      },
                    );
```

- [ ] **Step 3: Add error/empty-search state to ShoppingView product list**

In `lib/features/shopping/presentation/views/shopping_view.dart`, find the Consumer that renders the product list:

Find this block inside the product list Consumer:
```dart
                            if (viewModel.isLoading &&
                                viewModel.products.isEmpty) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
```

Replace with:
```dart
                            if (viewModel.isLoading &&
                                viewModel.products.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 64),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }

                            if (viewModel.errorMessage != null &&
                                viewModel.products.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.wifi_off,
                                        size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text(
                                      viewModel.errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.grey),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          viewModel.loadProducts(),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (!viewModel.isLoading &&
                                viewModel.products.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off,
                                        size: 64,
                                        color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      viewModel.searchQuery.isNotEmpty
                                          ? 'No results for "${viewModel.searchQuery}"'
                                          : 'No products found',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                              );
                            }
```

- [ ] **Step 4: Verify compile**

```bash
cd /home/user/Documents/Calling/SuperApp
flutter analyze lib/features/shopping/presentation/views/widgets/shopping_search_bar.dart lib/features/shopping/presentation/views/shopping_view.dart 2>&1 | grep -E "^  error" | head -20
```

Expected: zero errors.

- [ ] **Step 5: Commit**

```bash
cd /home/user/Documents/Calling/SuperApp
git add lib/features/shopping/presentation/views/widgets/shopping_search_bar.dart \
        lib/features/shopping/presentation/views/shopping_view.dart
git commit -m "feat(flutter): wire product search bar with clear button and error/empty states"
```

---

## Task 9: Flutter — Shipping Addresses Screen

**Files:**
- Create: `lib/services/shipping_address_service.dart`
- Create: `lib/features/profile/presentation/views/shipping_addresses_view.dart`
- Modify: `lib/features/profile/presentation/views/profile_view.dart`

- [ ] **Step 1: Create ShippingAddressService**

Create `lib/services/shipping_address_service.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ShippingAddress {
  final String id;
  final String userId;
  final String label;
  final String address;
  final String city;
  final String phone;
  final bool isDefault;

  const ShippingAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.address,
    this.city = '',
    this.phone = '',
    this.isDefault = false,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      id: json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class ShippingAddressService {
  static const String _base = 'https://superapp-diht.onrender.com/api';

  Future<List<ShippingAddress>> fetchAddresses(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_base/shipping-addresses?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => ShippingAddress.fromJson(j)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<ShippingAddress?> addAddress({
    required String userId,
    required String label,
    required String address,
    String city = '',
    String phone = '',
    bool isDefault = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/shipping-addresses'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'label': label,
          'address': address,
          'city': city,
          'phone': phone,
          'isDefault': isDefault,
        }),
      );
      if (response.statusCode == 201) {
        return ShippingAddress.fromJson(json.decode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteAddress(String id, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_base/shipping-addresses/$id?userId=${Uri.encodeComponent(userId)}'),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 2: Create ShippingAddressesView**

Create `lib/features/profile/presentation/views/shipping_addresses_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/services/shipping_address_service.dart';

class ShippingAddressesView extends StatefulWidget {
  const ShippingAddressesView({super.key});

  @override
  State<ShippingAddressesView> createState() => _ShippingAddressesViewState();
}

class _ShippingAddressesViewState extends State<ShippingAddressesView> {
  final ShippingAddressService _service = ShippingAddressService();
  List<ShippingAddress> _addresses = [];
  bool _isLoading = true;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creds = await getIt<OtpAuthService>().getStoredCredentials();
    _userId = creds?['username'] ?? '';
    if (_userId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final addresses = await _service.fetchAddresses(_userId);
    if (mounted) setState(() { _addresses = addresses; _isLoading = false; });
  }

  Future<void> _showAddDialog() async {
    final labelCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Address'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label (e.g. Home)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Street Address'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    await _service.addAddress(
      userId: _userId,
      label: labelCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      city: cityCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      isDefault: _addresses.isEmpty,
    );
    await _load();
  }

  Future<void> _delete(ShippingAddress addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Remove "${addr.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteAddress(addr.id, _userId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping Addresses'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add address',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No addresses saved',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Address'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final addr = _addresses[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: addr.isDefault
                            ? Border.all(
                                color: WunzaColors.primary, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: WunzaColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on,
                              color: WunzaColors.primary),
                        ),
                        title: Row(
                          children: [
                            Text(addr.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            if (addr.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: WunzaColors.primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Default',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: WunzaColors.primary,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(addr.address),
                            if (addr.city.isNotEmpty) Text(addr.city),
                            if (addr.phone.isNotEmpty)
                              Text(addr.phone,
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _delete(addr),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _addresses.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: WunzaColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
```

- [ ] **Step 3: Wire ShippingAddressesView from profile_view.dart**

In `lib/features/profile/presentation/views/profile_view.dart`, add the import at the top:

```dart
import '../../../features/profile/presentation/views/shipping_addresses_view.dart';
```

Wait — the file is already in `lib/features/profile/presentation/views/`. Use a relative import:

Add at the top of the import section in `profile_view.dart`:
```dart
import 'shipping_addresses_view.dart';
```

Then find:
```dart
                          _buildTile(
                            icon: Icons.location_on_outlined,
                            title: 'Shipping Addresses',
                            subtitle: 'Manage delivery locations',
                            isDark: isDark,
                            onTap: () => _navigateTo(context,
                                const _PlaceholderScreen(title: 'Shipping Addresses')),
                          ),
```

Replace `onTap` with:
```dart
                            onTap: () => _navigateTo(context, const ShippingAddressesView()),
```

- [ ] **Step 4: Verify compile**

```bash
cd /home/user/Documents/Calling/SuperApp
flutter analyze lib/services/shipping_address_service.dart lib/features/profile/presentation/views/shipping_addresses_view.dart lib/features/profile/presentation/views/profile_view.dart 2>&1 | grep -E "^  error" | head -20
```

Expected: zero errors.

- [ ] **Step 5: Commit**

```bash
cd /home/user/Documents/Calling/SuperApp
git add lib/services/shipping_address_service.dart \
        lib/features/profile/presentation/views/shipping_addresses_view.dart \
        lib/features/profile/presentation/views/profile_view.dart
git commit -m "feat(flutter): add shipping addresses screen wired to backend"
```

---

## Task 10: Final Integration Test & Rotate Secrets

**Files:**
- `backend/.env` (rotate secrets)

- [ ] **Step 1: Generate a strong JWT secret**

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Copy the output — this is your new `JWT_SECRET`.

- [ ] **Step 2: Update backend/.env**

Open `backend/.env` and replace `JWT_SECRET=supersecretkey_dev_only` with the generated value. Do NOT commit this change to git — `.env` should already be in `.gitignore`.

```
MONGO_URI=mongodb+srv://...
PORT=5000
JWT_SECRET=<paste-generated-32-byte-hex-here>
```

- [ ] **Step 3: On Render, update the environment variable**

Log in to Render dashboard → SuperApp backend service → Environment → update `JWT_SECRET` to the same generated value. Redeploy.

- [ ] **Step 4: Run a full flutter analyze**

```bash
cd /home/user/Documents/Calling/SuperApp
flutter analyze lib/ 2>&1 | grep -E "^  error" | head -30
```

Expected: zero errors.

- [ ] **Step 5: Test the backend**

```bash
# Test register (should NOT accept role)
curl -s -X POST https://superapp-diht.onrender.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass","role":"super_admin"}' | jq .

# Verify role is 'staff' in response (or check DB)
curl -s -X POST https://superapp-diht.onrender.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}' | jq .role
```

Expected: `"staff"` — not `"super_admin"`.

- [ ] **Step 6: Test cart API**

```bash
# Add to cart
curl -s -X POST https://superapp-diht.onrender.com/api/cart/add \
  -H "Content-Type: application/json" \
  -d '{"userId":"testuser","productId":"<any-product-id-from-db>","quantity":2}' | jq .

# Get cart
curl -s "https://superapp-diht.onrender.com/api/cart?userId=testuser" | jq .
```

Expected: cart response with `items`, `total`, `item_count`.

- [ ] **Step 7: Test payment proxy**

```bash
curl -s -X POST https://superapp-diht.onrender.com/api/payments/africom/superapp-pay \
  -H "Content-Type: application/json" \
  -d '{"amount":10.00,"currency":"USD","reference":"TEST-1","user_id":"testuser","channel":"ewallet"}' | jq .
```

Expected: `{"status":"success","paid":true,"transaction_id":"TXN-...","message":"Payment processed successfully"}`

- [ ] **Step 8: Final commit**

```bash
cd /home/user/Documents/Calling/SuperApp
# .env should NOT be staged — confirm
git status
git commit --allow-empty -m "chore: production readiness complete — all 18 fixes applied"
```

---

## Self-Review Checklist

| Requirement | Task |
|---|---|
| 1. Fix register role injection | Task 2 Step 1 |
| 2. Add upload auth | Task 2 Step 2 |
| 3. Add Helmet + rate-limit | Task 1 |
| 4. Rotate secrets | Task 10 |
| 5. Add orders API | Task 4 |
| 6. Add cart persistence API | Task 3 |
| 7. Add wishlist API | Task 5 |
| 8. Implement payment proxy | Task 5 |
| 9. Fix mass-assignment on products PUT | Task 2 Step 4 |
| 10. Increment usedCount | Task 2 Step 5 |
| 11. Delete fake AuthService | Task 6 |
| 12. Connect cart to backend | Task 7 |
| 13. Connect orders to backend | Task 7 |
| 14. Fix "Staples" hardcode | Task 7 Step 3 Fix 1 |
| 15. Fix checkout button label | Task 7 Step 3 Fix 2 |
| 16. Wire search bar | Task 8 |
| 17. Add error/offline states | Task 8 Step 3 |
| 18. Shipping addresses screen | Task 9 |

All 18 requirements covered. ✓
