const jwt = require('jsonwebtoken');

const getToken = (req) => req.cookies?.token || req.headers.authorization?.split(' ')[1];

const signAdminToken = (user) =>
    jwt.sign(
        { id: user._id, role: user.role, username: user.username, aud: 'admin' },
        process.env.JWT_SECRET,
        { expiresIn: '1d' }
    );

const signAppToken = (appUser) =>
    jwt.sign(
        { sub: String(appUser._id), username: appUser.sipUsername, aud: 'app' },
        process.env.JWT_SECRET,
        { expiresIn: '7d' }
    );

// Returns { id, username } for a valid app-audience token, otherwise null.
const verifyAppToken = (token) => {
    if (!token) return null;
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (decoded.aud !== 'app' || !decoded.sub) return null;
        return { id: String(decoded.sub), username: decoded.username };
    } catch (error) {
        return null;
    }
};

const requireAdmin = (roles) => (req, res, next) => {
    const token = getToken(req);
    if (!token) {
        return res.status(401).json({ message: 'Authentication failed: No token provided' });
    }
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (decoded.aud !== 'admin') {
            return res.status(401).json({ message: 'Authentication failed: Invalid token' });
        }
        req.user = { id: decoded.id, role: decoded.role, username: decoded.username };
    } catch (error) {
        return res.status(401).json({ message: 'Authentication failed: Invalid token' });
    }
    if (Array.isArray(roles) && roles.length && !roles.includes(req.user.role)) {
        return res.status(403).json({ message: 'Forbidden' });
    }
    next();
};

const requireAppUser = (req, res, next) => {
    const token = getToken(req);
    if (!token) {
        return res.status(401).json({ message: 'Authentication failed: No token provided' });
    }
    const appUser = verifyAppToken(token);
    if (!appUser) {
        return res.status(401).json({ message: 'Authentication failed: Invalid token' });
    }
    req.appUser = appUser;
    next();
};

module.exports = { requireAdmin, requireAppUser, signAdminToken, signAppToken, verifyAppToken };
