const express = require('express');
const AppUser = require('../models/app_user.model');
const { verifyCredentials } = require('../africom/verifier');
const { requireAppUser, signAppToken } = require('../middleware/auth.middleware');
const { appSessionIpLimiter, appSessionAccountLimiter } = require('../middleware/rate_limits');
const { canonicalUsername } = require('../lib/phone');

const router = express.Router();

const BAD_INPUT = { message: 'Phone number and password are required.' };
const MAX_USERNAME = 32;
const MAX_PASSWORD = 128;

const toUserDto = (u) => ({
  id: String(u._id),
  username: u.sipUsername,
  displayName: u.displayName || null,
});

// Validates the body and sets req.sessionUsername (canonical) for the account limiter.
const validateSessionInput = (req, res, next) => {
  const { username, password, displayName } = req.body || {};
  if (typeof username !== 'string' || typeof password !== 'string') {
    return res.status(400).json(BAD_INPUT);
  }
  const trimmed = username.trim();
  if (!trimmed || trimmed === '+' || !password) {
    return res.status(400).json(BAD_INPUT);
  }
  if (trimmed.length > MAX_USERNAME || password.length > MAX_PASSWORD) {
    return res.status(400).json(BAD_INPUT);
  }
  if (displayName !== undefined && typeof displayName !== 'string') {
    return res.status(400).json(BAD_INPUT);
  }
  req.sessionUsername = canonicalUsername(trimmed);
  next();
};

const createSession = async (req, res) => {
  const { password, displayName } = req.body;
  const trimmed = req.body.username.trim();

  try {
    const result = await verifyCredentials(trimmed, password);
    if (!result.ok) {
      if (result.reason === 'unavailable') {
        return res
          .status(503)
          .json({ message: 'Verification service unavailable. Try again shortly.' });
      }
      return res.status(401).json({ message: 'Phone number or password is incorrect.' });
    }

    // The verifier may accept the number with or without '+'; store one canonical form
    // so both logins map to the same AppUser and the same user-scoped data.
    const sipUsername = canonicalUsername(result.username);
    const set = { lastSessionAt: new Date() };
    const name = typeof displayName === 'string' ? displayName.trim().slice(0, 80) : '';
    if (name) set.displayName = name;

    const user = await AppUser.findOneAndUpdate(
      { sipUsername },
      { $set: set, $setOnInsert: { sipUsername } },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    return res.json({ token: signAppToken(user), user: toUserDto(user) });
  } catch (err) {
    return res.status(500).json({ message: 'Could not create session.' });
  }
};

// IP limit first, then validation (the account key needs a validated username).
router.post(
  '/session',
  appSessionIpLimiter,
  validateSessionInput,
  appSessionAccountLimiter,
  createSession
);

router.get('/me', requireAppUser, async (req, res) => {
  try {
    const user = await AppUser.findById(req.appUser.id);
    if (!user) return res.status(401).json({ message: 'Unauthorized' });
    return res.json(toUserDto(user));
  } catch (err) {
    return res.status(500).json({ message: 'Could not load user.' });
  }
});

module.exports = router;
