const fs = require('fs');
const { getToken, verifyAppToken } = require('./auth.middleware');

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

// Sets req.userId (the SIP username, never the Mongo _id) from the app session token.
// With LEGACY_USERID_ROUTES === 'true' and no token, falls back to the client-supplied `field`.
// An invalid token is rejected even in legacy mode.
// required: false lets anonymous and invalid-token requests through with req.userId undefined.
const resolveUser = ({ field, required = true }) => (req, res, next) => {
    const token = getToken(req);
    let userId;

    if (token) {
        const appUser = verifyAppToken(token);
        if (appUser && appUser.username) {
            userId = appUser.username;
        } else if (required) {
            return unauthorized(req, res);
        }
    } else if (legacyEnabled()) {
        const legacyId = req.body?.[field] ?? req.query?.[field];
        if (typeof legacyId === 'string' && legacyId) userId = legacyId;
    }

    stripBodyIds(req);

    if (!userId && required) return unauthorized(req, res);
    req.userId = userId;
    next();
};

module.exports = { resolveUser };
