const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

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

// Rate limiting on auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20,
  message: { message: 'Too many requests, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(express.json());

const path = require('path');
const multer = require('multer');
const fs = require('fs');
const auth = require('./middleware/auth.middleware');

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

// Database Connection
mongoose.connect(process.env.MONGO_URI)
    .then(() => console.log('Successfully connected to MongoDB'))
    .catch((err) => console.error('Could not connect to MongoDB:', err));

// Serve static files from 'uploads' directory
app.use('/uploads', express.static('uploads'));

// Routes
app.post('/api/upload', auth, upload.single('image'), (req, res) => {
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
const Shop = require('./models/shop.model');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// Auth Routes
app.post('/api/auth/register', authLimiter, async (req, res) => {
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

        const token = jwt.sign(
            { id: user._id, role: user.role, username: user.username },
            process.env.JWT_SECRET,
            { expiresIn: '1d' }
        );

        res.json({ token, user: { id: user._id, username: user.username, role: user.role } });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});


// Get all products (with pagination)
app.get('/api/products', async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const skip = (page - 1) * limit;

        const filter = { isDeleted: false };
        if (req.query.category && req.query.category !== 'All') {
            filter.category = req.query.category;
        }

        const totalProducts = await Product.countDocuments(filter);
        const totalPages = Math.ceil(totalProducts / limit);

        const products = await Product.find(filter)
            .skip(skip)
            .limit(limit);

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
app.post('/api/products', auth, async (req, res) => {
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
        if (!updatedProduct) {
            return res.status(404).json({ message: 'Product not found' });
        }
        res.json(updatedProduct);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Soft Delete a product
app.delete('/api/products/:id', auth, async (req, res) => {
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
app.post('/api/categories', auth, async (req, res) => {
    const category = new Category(req.body);
    try {
        const newCategory = await category.save();
        res.status(201).json(newCategory);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Update Category
app.put('/api/categories/:id', auth, async (req, res) => {
    try {
        const updatedCategory = await Category.findByIdAndUpdate(req.params.id, req.body, { new: true });
        res.json(updatedCategory);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Delete Category
app.delete('/api/categories/:id', auth, async (req, res) => {
    try {
        await Category.findByIdAndDelete(req.params.id);
        res.json({ message: 'Category deleted' });
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
app.post('/api/shops', auth, async (req, res) => {
    const shop = new Shop(req.body);
    try {
        const newShop = await shop.save();
        res.status(201).json(newShop);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Update Shop
app.put('/api/shops/:id', auth, async (req, res) => {
    try {
        const updatedShop = await Shop.findByIdAndUpdate(req.params.id, req.body, { new: true });
        res.json(updatedShop);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Delete Shop
app.delete('/api/shops/:id', auth, async (req, res) => {
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
app.post('/api/banners', auth, async (req, res) => {
    const banner = new Banner(req.body);
    try {
        const newBanner = await banner.save();
        res.status(201).json(newBanner);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Update Banner
app.put('/api/banners/:id', auth, async (req, res) => {
    try {
        const updatedBanner = await Banner.findByIdAndUpdate(req.params.id, req.body, { new: true });
        res.json(updatedBanner);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Delete Banner
app.delete('/api/banners/:id', auth, async (req, res) => {
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
app.post('/api/vouchers', auth, async (req, res) => { // Auth required for creation
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
// Global error handler — catches Multer rejections and other middleware errors
app.use((err, req, res, next) => {
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ message: 'File too large. Maximum size is 5 MB.' });
  }
  if (err.message && err.message.includes('Only JPEG')) {
    return res.status(415).json({ message: err.message });
  }
  console.error(err);
  res.status(500).json({ message: 'Internal server error' });
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
