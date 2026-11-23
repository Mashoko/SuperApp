const fs = require('fs');
const { getToken, verifyAppToken } = require('./auth.middleware');
const { canonicalUsername } = require('../lib/phone');

const ID_FIELDS = ['userId', 'user_id', 'authorUserId'];

const legacyEnabled = () => process.env.LEGACY_USERID_ROUTES === 'true';

// Multipart routes run this after multer, so a rejected request may already have a file on disk.
const discardUpload = (req) => {
    if (!req.file?.path) return;
    try {
        fs.unlinkSync(req.file.path);
    } catch (error) {
        // Already gone; nothing to clean up.
    }
};

const unauthorized = (req, res) => {
    discardUpload(req);
    return res.status(401).json({ message: 'Sign in required.' });
};

// Removes client-supplied identity fields from the body so handlers cannot read them.
// req.query is re-parsed on every access in Express 5 and cannot be stripped,
// so handlers must read identity from req.userId only.
const stripBodyIds = (req) => {
    if (!req.body || typeof req.body !== 'object') return;
    for (const key of ID_FIELDS) delete req.body[key];
};

// In-memory counts of identified requests, for deciding when to turn legacy mode off.
// No ids are kept. Reset on every process start (each deploy).
const usage = { tokenRequests: 0, legacyRequests: 0, since: new Date().toISOString() };
const getLegacyUsage = () => ({ ...usage });

// Sets req.userId (the SIP username, never the Mongo _id) from the app session token.
// With LEGACY_USERID_ROUTES === 'true' and no token, falls back to the client-supplied `field`.
// An invalid token is rejected even in legacy mode.
// required: false lets anonymous and invalid-token requests through with req.userId undefined.
// Also sets req.auth: { via: 'token', appUserId } or { via: 'legacy' }; undefined when anonymous.
// Legacy identity is unverified, so anything that needs a proven identity must check req.auth.via.
const resolveUser = ({ field, required = true }) => (req, res, next) => {
    const token = getToken(req);
    let userId;
    let auth;

    if (token) {
        const appUser = verifyAppToken(token);
        if (appUser && appUser.username) {
            userId = appUser.username;
            auth = { via: 'token', appUserId: appUser.id };
        } else if (required) {
            return unauthorized(req, res);
        }
    } else if (legacyEnabled()) {
        const legacyId = req.body?.[field] ?? req.query?.[field];
        if (typeof legacyId === 'string' && legacyId.trim()) {
            userId = canonicalUsername(legacyId);
            auth = { via: 'legacy' };
        }
    }

    stripBodyIds(req);

    if (!userId && required) return unauthorized(req, res);
    if (auth?.via === 'token') usage.tokenRequests += 1;
    if (auth?.via === 'legacy') usage.legacyRequests += 1;
    req.userId = userId;
    req.auth = auth;
    next();
};

module.exports = { resolveUser, getLegacyUsage, discardUpload };
