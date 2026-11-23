const express = require('express');
const AppUser = require('../../models/app_user.model');
const Notification = require('../models/notification.model');
const { resolveUser } = require('../../middleware/resolve_user.middleware');

// Not behind requireKycAccess: restricted users must still be able to read why.
const router = express.Router();

const PAGE_SIZE = 20;
const OBJECT_ID = /^[0-9a-f]{24}$/i;
const SIGN_IN = { message: 'Sign in required.' };
const NOT_FOUND = { message: 'Notification not found.' };
const GENERIC = { message: 'Something went wrong.' };

const handle = (fn) => async (req, res, next) => {
  try {
    await fn(req, res, next);
  } catch (err) {
    // Never sends or logs err.message: it can carry user data.
    console.error('Notification route error:', err?.name, err?.code);
    res.status(500).json(GENERIC);
  }
};

const toItem = (n) => ({
  id: String(n._id),
  kind: n.kind,
  title: n.title,
  body: n.body,
  createdAt: n.createdAt,
  readAt: n.readAt || null,
});

// Requires a verified session token and loads the AppUser by the token's subject.
const requireAppUser = handle(async (req, res, next) => {
  if (req.auth?.via !== 'token') return res.status(401).json(SIGN_IN);
  const id = req.auth.appUserId;
  if (typeof id !== 'string' || !OBJECT_ID.test(id)) return res.status(401).json(SIGN_IN);
  const appUser = await AppUser.findById(id).select('_id sipUsername');
  if (!appUser || appUser.sipUsername !== req.userId) return res.status(401).json(SIGN_IN);
  req.appUserId = appUser._id;
  next();
});

router.use(resolveUser({ field: 'userId' }), requireAppUser);

router.get(
  '/',
  handle(async (req, res) => {
    const requested = Number.parseInt(req.query.page, 10);
    const page = Number.isInteger(requested) && requested > 0 ? requested : 1;
    const own = { appUserId: req.appUserId };
    const [items, total, unread] = await Promise.all([
      Notification.find(own)
        .sort({ createdAt: -1, _id: -1 })
        .skip((page - 1) * PAGE_SIZE)
        .limit(PAGE_SIZE)
        .lean(),
      Notification.countDocuments(own),
      Notification.countDocuments({ ...own, readAt: null }),
    ]);
    res.json({
      items: items.map(toItem),
      unread,
      page,
      totalPages: Math.ceil(total / PAGE_SIZE),
    });
  })
);

router.post(
  '/:id/read',
  handle(async (req, res) => {
    const { id } = req.params;
    if (!OBJECT_ID.test(id)) return res.status(404).json(NOT_FOUND);
    const own = { _id: id, appUserId: req.appUserId };
    // Keeps the first readAt when marked twice.
    await Notification.updateOne({ ...own, readAt: null }, { $set: { readAt: new Date() } });
    const n = await Notification.findOne(own).lean();
    if (!n) return res.status(404).json(NOT_FOUND);
    res.json(toItem(n));
  })
);

module.exports = router;
