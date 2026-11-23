const AppUser = require('../models/app_user.model');
const KycSettings = require('./models/kyc_settings.model');
const KycEvent = require('./models/kyc_event.model');
const { computeKycState } = require('./schedule');
const { discardUpload } = require('../middleware/resolve_user.middleware');

const OBJECT_ID = /^[0-9a-f]{24}$/i;
const SIGN_IN = { message: 'Sign in required.' };
const GENERIC = { message: 'Something went wrong.' };
const RESTRICTED_MESSAGE = 'Complete your KYC verification to keep using this feature.';

// Logs only the error's name and code: messages can carry user data.
const logBookkeepingError = (err) => {
  console.error('KYC restriction bookkeeping failed:', err?.name, err?.code);
};

// Inserts an event once per idempotency key; a duplicate means it is already recorded.
const recordOnce = async (event) => {
  try {
    await KycEvent.create(event);
  } catch (err) {
    if (err?.code !== 11000) throw err;
  }
};

// Writes the RESTRICTED event, then caches restrictedAt. The event goes first so a failed
// insert leaves restrictedAt unset and the next blocked request (or the reminder job)
// retries it; the idempotency key keeps it to one event per cycle.
// Never sends a notification: those come from the reminder job's RESTRICTED stage.
const markRestricted = async (appUser, now) => {
  const cycle = Number(appUser.kyc?.cycle) || 0;
  await recordOnce({
    appUserId: appUser._id,
    actor: 'system',
    type: 'RESTRICTED',
    data: { cycle },
    idempotencyKey: `${appUser._id}:restricted:${cycle}`,
  });
  await AppUser.findOneAndUpdate(
    { _id: appUser._id, 'kyc.restrictedAt': null },
    { $set: { 'kyc.restrictedAt': now } }
  );
};

const clearRestricted = async (appUser) => {
  const cleared = await AppUser.findOneAndUpdate(
    { _id: appUser._id, 'kyc.restrictedAt': { $ne: null } },
    { $unset: { 'kyc.restrictedAt': 1 } }
  );
  if (!cleared) return;
  await KycEvent.create({
    appUserId: appUser._id,
    actor: 'system',
    type: 'UNRESTRICTED',
    data: { reason: 'no_longer_restricted' },
  });
};

// Bookkeeping must never change the response, so its errors are logged and swallowed.
const bookkeep = async (fn) => {
  try {
    await fn();
  } catch (err) {
    logBookkeepingError(err);
  }
};

// Blocks token-authenticated users past their KYC deadline. Mount after resolveUser.
// Legacy (unverified userId) requests are let through: enforcement needs
// LEGACY_USERID_ROUTES=false. Settings are read per request so admin changes apply at once.
const requireKycAccess = async (req, res, next) => {
  if (req.auth?.via !== 'token') return next();

  let appUser;
  let state;
  const now = new Date();
  try {
    const id = req.auth.appUserId;
    if (typeof id === 'string' && OBJECT_ID.test(id)) appUser = await AppUser.findById(id);
    if (!appUser || appUser.sipUsername !== req.userId) {
      discardUpload(req);
      return res.status(401).json(SIGN_IN);
    }
    const settings = await KycSettings.getSettings();
    state = computeKycState(appUser, settings, now);
  } catch (err) {
    console.error('KYC access check failed:', err?.name, err?.code);
    discardUpload(req);
    return res.status(500).json(GENERIC);
  }

  if (state.restricted) {
    if (!appUser.kyc?.restrictedAt) await bookkeep(() => markRestricted(appUser, now));
    discardUpload(req);
    return res.status(403).json({
      code: 'KYC_RESTRICTED',
      message: RESTRICTED_MESSAGE,
      status: 'RESTRICTED',
      underlyingStatus: state.underlyingStatus,
      deadline: state.deadline,
    });
  }

  if (appUser.kyc?.restrictedAt) await bookkeep(() => clearRestricted(appUser));
  return next();
};

module.exports = { requireKycAccess };
