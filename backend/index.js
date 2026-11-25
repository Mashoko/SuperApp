const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Behind a reverse proxy (Render) req.ip is the proxy's address unless Express trusts
// X-Forwarded-For; without this every client shares one rate-limit bucket.
// TRUST_PROXY is the number of proxy hops; on Render it defaults to 1.
if (process.env.TRUST_PROXY) {
  app.set('trust proxy', Number(process.env.TRUST_PROXY));
} else if (process.env.RENDER) {
  app.set('trust proxy', 1);
}

// Security headers
// crossOriginResourcePolicy is relaxed so that images served from /uploads
// can be loaded by the Flutter app and admin panel from different origins.
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));

// CORS — restrict to known origins
const extraOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
  : ['https://superapp-diht.onrender.com'];

app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:8080', ...extraOrigins],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

const { authLimiter } = require('./middleware/rate_limits');

app.use(express.json());

const path = require('path');
const multer = require('multer');
const fs = require('fs');
const { requireAdmin, signAdminToken } = require('./middleware/auth.middleware');

// Staff roles that manage the shop: catalogue, shops, banners, vouchers, FAQs, uploads and
// order status. kyc_reviewer is deliberately left out.
const SHOP_ADMIN_ROLES = ['super_admin', 'shop_manager', 'staff'];
const { resolveUser, getLegacyUsage } = require('./middleware/resolve_user.middleware');
const { requireKycAccess } = require('./kyc/require_kyc_access.middleware');

// Ensure uploads directory exists
const uploadDir = 'uploads';
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir);
}

// Multer Storage Configuration
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/')
    },
    filename: function (req, file, cb) {
        // Use timestamp to prevent name collisions
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

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

// Database Connection
mongoose.connect(process.env.MONGO_URI)
    .then(() => console.log('Successfully connected to MongoDB'))
    .catch((err) => console.error('Could not connect to MongoDB:', err));

// Serve static files from 'uploads' directory
app.use('/uploads', express.static('uploads'));

// Routes
app.post('/api/upload', requireAdmin(SHOP_ADMIN_ROLES), upload.single('image'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ message: 'No file uploaded.' });
    }
    // Return the full URL to the uploaded file
    // Note: Use the request host/protocol to construct URL
    // Important: For Render, this points to the ephemeral storage URL
    const protocol = req.protocol;
    const host = req.get('host');
    const fileUrl = `${protocol}://${host}/uploads/${req.file.filename}`;
    res.json({ imageUrl: fileUrl });
});

// Routes
app.get('/', (req, res) => {
    res.send('Backend is running!');
});

const Product = require('./models/product.model');
const User = require('./models/user.model');
const Category = require('./models/category.model');
const Faq = require('./models/faq.model');
const Shop = require('./models/shop.model');
const bcrypt = require('bcryptjs');

// Auth Routes
app.use('/api/app-auth', require('./routes/app_auth.routes'));
app.use('/api/kyc', require('./kyc/routes/kyc_user.routes'));
app.use('/api/notifications', require('./kyc/routes/notifications.routes'));
app.use('/api/admin/kyc', require('./kyc/routes/kyc_admin.routes'));
app.post('/api/auth/register', authLimiter, requireAdmin(['super_admin']), async (req, res) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) {
          return res.status(400).json({ message: 'Username and password are required' });
        }
        const user = new User({ username, password }); // role defaults to 'staff' in schema
        await user.save();
        res.status(201).json({ message: 'User created successfully' });
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Token vs legacy-fallback request counts since this process started (see docs/app-sessions.md).
app.get('/api/admin/legacy-usage', requireAdmin(['super_admin']), (req, res) => {
    res.json(getLegacyUsage());
});

app.post('/api/auth/login', authLimiter, async (req, res) => {
    try {
        const { username, password } = req.body;
        const user = await User.findOne({ username });
        if (!user) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        const isMatch = await user.comparePassword(password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        const token = signAdminToken(user);

        res.json({ token, user: { id: user._id, username: user.username, role: user.role } });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});


// Get all products (with pagination)
app.get('/api/products', resolveUser({ field: 'userId', required: false }), async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const skip = (page - 1) * limit;

        const filter = { isDeleted: false };
        if (req.query.category && req.query.category !== 'All') {
            filter.category = req.query.category;
        }
        if (req.query.search && req.query.search.trim() !== '') {
            const escaped = req.query.search.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const searchRegex = new RegExp(escaped, 'i');
            filter.$or = [{ name: searchRegex }, { description: searchRegex }];
        }

        let sort = null;

        if (req.query.sort === 'trending') {
            filter.isTrending = true;
            sort = { averageRating: -1, createdAt: -1 };
        } else if (req.query.sort === 'recommended') {
            const userId = req.userId;
            let categories = [];
            let excludeIds = [];

            if (userId) {
                const wishlist = await Wishlist.findOne({ userId });
                const wishlistProductIds = wishlist
                    ? wishlist.productIds.map((id) => id.toString())
                    : [];
                const cart = await Cart.findOne({ userId });
                const cartProductIds = cart
                    ? cart.items.map((item) => item.productId.toString())
                    : [];
                excludeIds = [...new Set([...wishlistProductIds, ...cartProductIds])];

                if (wishlistProductIds.length > 0) {
                    const wishlistProducts = await Product.find({
                        _id: { $in: wishlistProductIds },
                    });
                    categories = [
                        ...new Set(wishlistProducts.map((p) => p.category).filter(Boolean)),
                    ];
                }
            }

            if (categories.length > 0) {
                filter.category = { $in: categories };
            }
            if (excludeIds.length > 0) {
                filter._id = { $nin: excludeIds };
            }
            sort =
                categories.length > 0
                    ? { averageRating: -1, createdAt: -1 }
                    : { createdAt: -1, averageRating: -1 };
        }

        const totalProducts = await Product.countDocuments(filter);
        const totalPages = Math.ceil(totalProducts / limit);

        let query = Product.find(filter);
        if (sort) query = query.sort(sort);
        const products = await query.skip(skip).limit(limit);

        res.json({
            products,
            totalPages,
            currentPage: page,
            totalProducts
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Create a product
app.post('/api/products', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    const product = new Product({
        name: req.body.name,
        description: req.body.description,
        price: req.body.price,
        imageUrl: req.body.imageUrl,
        category: req.body.category,
        stock: req.body.stock,
        discountPrice: req.body.discountPrice,
        isAvailable: req.body.isAvailable
    });

    try {
        const newProduct = await product.save();
        res.status(201).json(newProduct);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Update a product
app.put('/api/products/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
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
        if (!updatedProduct) {
            return res.status(404).json({ message: 'Product not found' });
        }
        res.json(updatedProduct);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Soft Delete a product
app.delete('/api/products/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    try {
        await Product.findByIdAndUpdate(req.params.id, { isDeleted: true });
        res.json({ message: 'Product deleted' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// --- Category Routes ---
// Get all categories
// Get all categories (optional filter: ?hasProducts=true)
app.get('/api/categories', async (req, res) => {
    try {
        let categories = await Category.find();

        if (req.query.hasProducts === 'true') {
            // Find distinct categories that have active products
            const activeProductCategories = await Product.distinct('category', {
                isDeleted: false,
                isAvailable: true
            });

            // Filter categories ensuring we only return those that are used
            // Note: Since Product.category stores the name string, we match by name.
            categories = categories.filter(cat => activeProductCategories.includes(cat.name));
        }

        res.json(categories);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Create Category
app.post('/api/categories', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    const category = new Category(req.body);
    try {
        const newCategory = await category.save();
        res.status(201).json(newCategory);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Update Category
app.put('/api/categories/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    try {
        const updatedCategory = await Category.findByIdAndUpdate(req.params.id, req.body, { new: true });
        res.json(updatedCategory);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Delete Category
app.delete('/api/categories/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    try {
        await Category.findByIdAndDelete(req.params.id);
        res.json({ message: 'Category deleted' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

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
app.post('/api/faqs', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    const faq = new Faq(req.body);
    try {
        const newFaq = await faq.save();
        res.status(201).json(newFaq);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Update FAQ category
app.put('/api/faqs/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    try {
        const updatedFaq = await Faq.findByIdAndUpdate(req.params.id, req.body, { new: true });
        res.json(updatedFaq);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Delete FAQ category
app.delete('/api/faqs/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    try {
        await Faq.findByIdAndDelete(req.params.id);
        res.json({ message: 'FAQ category deleted' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// --- Shop Routes ---
// Get all shops
app.get('/api/shops', async (req, res) => {
    try {
        const shops = await Shop.find();
        res.json(shops);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Create Shop
app.post('/api/shops', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    const shop = new Shop(req.body);
    try {
        const newShop = await shop.save();
        res.status(201).json(newShop);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Update Shop
app.put('/api/shops/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    try {
        const updatedShop = await Shop.findByIdAndUpdate(req.params.id, req.body, { new: true });
        res.json(updatedShop);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Delete Shop
app.delete('/api/shops/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    try {
        await Shop.findByIdAndDelete(req.params.id);
        res.json({ message: 'Shop deleted' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// --- Banner Routes ---
const Banner = require('./models/banner.model');

// Get active banners
app.get('/api/banners', async (req, res) => {
    try {
        const banners = await Banner.find({ isActive: true });
        res.json(banners);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Create Banner
app.post('/api/banners', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    const banner = new Banner(req.body);
    try {
        const newBanner = await banner.save();
        res.status(201).json(newBanner);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Update Banner
app.put('/api/banners/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    try {
        const updatedBanner = await Banner.findByIdAndUpdate(req.params.id, req.body, { new: true });
        res.json(updatedBanner);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Delete Banner
app.delete('/api/banners/:id', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
    try {
        await Banner.findByIdAndDelete(req.params.id);
        res.json({ message: 'Banner deleted' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// --- Voucher Routes ---
const Voucher = require('./models/voucher.model');

// Get all vouchers
app.get('/api/vouchers', async (req, res) => {
    try {
        const vouchers = await Voucher.find().sort({ createdAt: -1 });
        res.json(vouchers);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Create Voucher
app.post('/api/vouchers', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => { // Auth required for creation
    const voucher = new Voucher(req.body);
    try {
        const newVoucher = await voucher.save();
        res.status(201).json(newVoucher);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Validate Voucher
app.post('/api/validate-voucher', async (req, res) => {
    try {
        const { code, cart_total } = req.body;
        const subtotal = parseFloat(cart_total);

        if (!code) {
            return res.status(400).json({ message: 'Voucher code is required' });
        }

        if (!cart_total || isNaN(subtotal) || subtotal < 0) {
            return res.status(400).json({ message: 'A valid cart_total is required' });
        }

        // First, find the voucher to check existence and gather error details
        const existing = await Voucher.findOne({ code: code.toUpperCase() });

        if (!existing) {
            return res.status(404).json({ message: 'Invalid voucher code' });
        }
        if (!existing.isActive) {
            return res.status(400).json({ message: 'Voucher is inactive' });
        }
        if (new Date() > new Date(existing.expirationDate)) {
            return res.status(400).json({ message: 'Voucher has expired' });
        }
        if (existing.usageLimit !== null && existing.usedCount >= existing.usageLimit) {
            return res.status(400).json({ message: 'Voucher usage limit reached' });
        }

        // Atomic increment — only succeeds if limit still not reached
        const voucher = await Voucher.findOneAndUpdate(
            {
                _id: existing._id,
                isActive: true,
                $or: [
                    { usageLimit: null },
                    { $expr: { $lt: ['$usedCount', '$usageLimit'] } }
                ]
            },
            { $inc: { usedCount: 1 } },
            { new: true }
        );

        if (!voucher) {
            return res.status(400).json({ message: 'Voucher usage limit reached' });
        }

        let discountAmount = 0.0;
        if (voucher.discountType === 'PERCENTAGE') {
            discountAmount = subtotal * (voucher.value / 100);
        } else {
            discountAmount = voucher.value;
        }

        if (discountAmount > subtotal) {
            discountAmount = subtotal;
        }

        res.json({
            valid: true,
            code: voucher.code,
            discount_amount: parseFloat(discountAmount.toFixed(2)),
            message: 'Voucher applied successfully'
        });

    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});
// --- Cart Routes ---
const Cart = require('./models/cart.model');

// Helper: populate cart items with product details and compute totals
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

// GET /api/cart  (identity from app session)
app.get('/api/cart', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const cart = await Cart.findOne({ userId });
    res.json(await buildCartResponse(cart));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/cart/add  { productId, quantity }
app.post('/api/cart/add', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const { productId, quantity = 1 } = req.body;
    if (!productId) return res.status(400).json({ message: 'productId required' });

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

// PUT /api/cart/update  { productId, quantity }
app.put('/api/cart/update', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const { productId, quantity } = req.body;
    if (!productId || quantity === undefined) {
      return res.status(400).json({ message: 'productId and quantity required' });
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

// DELETE /api/cart/remove  { productId }
app.delete('/api/cart/remove', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const { productId } = req.body ?? {};
    if (!productId) return res.status(400).json({ message: 'productId required' });

    const cart = await Cart.findOne({ userId });
    if (!cart) return res.status(404).json({ message: 'Cart not found' });

    cart.items = cart.items.filter((i) => i.productId.toString() !== productId);
    await cart.save();
    res.json(await buildCartResponse(cart));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE /api/cart/clear
app.delete('/api/cart/clear', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    await Cart.findOneAndUpdate({ userId }, { items: [] });
    res.json({ message: 'Cart cleared' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// --- Order Routes ---
const Order = require('./models/order.model');

// POST /api/orders  { items, shippingAddress, transactionId, paymentStatus, total, discountCode, discountAmount }
app.post('/api/orders', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const {
      items,
      shippingAddress,
      transactionId,
      paymentStatus = 'pending',
      total,
      discountCode,
      discountAmount = 0,
    } = req.body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'items are required' });
    }

    const orderId = `order_${Date.now()}_${userId}_${Math.random().toString(36).slice(2, 7)}`;

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

// GET /api/orders  (identity from app session)
app.get('/api/orders', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const orders = await Order.find({ user_id: userId }).sort({ createdAt: -1 });
    res.json(orders);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// PATCH /api/orders/:id/status  (admin)
app.patch('/api/orders/:id/status', requireAdmin(SHOP_ADMIN_ROLES), async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }
    const order = await Order.findByIdAndUpdate(req.params.id, { status }, { new: true });
    if (!order) return res.status(404).json({ message: 'Order not found' });
    res.json(order);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// --- Wishlist Routes ---
const Wishlist = require('./models/wishlist.model');

// GET /api/wishlist  (identity from app session)
app.get('/api/wishlist', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const wishlist = await Wishlist.findOne({ userId });
    const productIds = wishlist ? wishlist.productIds.map((id) => id.toString()) : [];
    const products = await Product.find({ _id: { $in: productIds }, isDeleted: false });
    res.json(products);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/wishlist/add  { productId }
app.post('/api/wishlist/add', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const { productId } = req.body;
    if (!productId) return res.status(400).json({ message: 'productId required' });
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

// DELETE /api/wishlist/remove/:productId  (identity from app session)
app.delete('/api/wishlist/remove/:productId', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const { productId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(productId)) {
      return res.status(400).json({ message: 'Invalid productId' });
    }
    await Wishlist.findOneAndUpdate({ userId }, { $pull: { productIds: productId } });
    res.json({ message: 'Removed from wishlist' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// --- Shipping Address Routes ---
const ShippingAddress = require('./models/shipping_address.model');

// GET /api/shipping-addresses  (identity from app session)
app.get('/api/shipping-addresses', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const addresses = await ShippingAddress.find({ userId }).sort({ isDefault: -1, createdAt: -1 });
    res.json(addresses);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/shipping-addresses  { label, address, city, phone, isDefault }
app.post('/api/shipping-addresses', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    const { label, address, city, phone, isDefault } = req.body;
    if (!label || !address) {
      return res.status(400).json({ message: 'label and address are required' });
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

// DELETE /api/shipping-addresses/:id  (identity from app session)
app.delete('/api/shipping-addresses/:id', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid address id' });
    }
    await ShippingAddress.findOneAndDelete({ _id: req.params.id, userId });
    res.json({ message: 'Address deleted' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// --- Payment Proxy ---
// POST /api/payments/africom/superapp-pay
app.post('/api/payments/africom/superapp-pay', resolveUser({ field: 'user_id' }), requireKycAccess, async (req, res) => {
  try {
    const user_id = req.userId;
    const { amount, currency, reference, channel } = req.body;
    if (!amount || !currency || !reference) {
      return res.status(400).json({ message: 'amount, currency, and reference are required' });
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

// ── Posts ──────────────────────────────────────────────────────────────────
const Post = require('./models/post.model');

app.post('/api/posts', postUpload.single('media'), resolveUser({ field: 'authorUserId' }), requireKycAccess, async (req, res) => {
  try {
    const authorUserId = req.userId;
    const { type, caption, authorName, audioTitle, durationSeconds } = req.body;

    if (!type || !['photo', 'video', 'text', 'audio'].includes(type)) {
      return res.status(400).json({ message: 'type must be one of: photo, video, text, audio' });
    }
    if (!authorName) {
      return res.status(400).json({ message: 'authorName is required' });
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

app.post('/api/posts/:id/like', resolveUser({ field: 'userId' }), requireKycAccess, async (req, res) => {
  try {
    const { userId } = req;
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ message: 'Post not found' });
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

app.delete('/api/posts/:id', resolveUser({ field: 'authorUserId' }), requireKycAccess, async (req, res) => {
  try {
    const authorUserId = req.userId;
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ message: 'Post not found' });
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

// Global error handler — catches Multer rejections and other middleware errors
app.use((err, req, res, next) => {
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ message: 'File too large.' });
  }
  if (err.message && (err.message.includes('Only JPEG') || err.message.includes('Unsupported media type'))) {
    return res.status(415).json({ message: err.message });
  }
  // Body-parser errors carry the raw request body (err.body), which can hold ID numbers
  // or passwords. Never log the error object, its body or its message.
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ message: 'Invalid request body.' });
  }
  if (err.type && err.status >= 400 && err.status < 500) {
    return res.status(err.status).json({ message: 'Invalid request body.' });
  }
  console.error('Unhandled error:', err.name, err.code, err.type);
  res.status(500).json({ message: 'Internal server error' });
});

if (require.main === module) {
  app.listen(PORT, () => {
      console.log(`Server is running on port ${PORT}`);
  });
  // The KYC reminder job never starts under tests (require.main is not this file there).
  const { kycKeyAvailable } = require('./kyc/crypto');
  if (process.env.KYC_JOB_ENABLED !== 'false' && kycKeyAvailable()) {
    require('./kyc/job').startKycJob();
  }
}

module.exports = app;
