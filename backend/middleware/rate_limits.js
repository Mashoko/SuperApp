const { rateLimit, ipKeyGenerator } = require('express-rate-limit');

const WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const message = { message: 'Too many requests, please try again later.' };

// Staff login and register.
const authLimiter = rateLimit({
  windowMs: WINDOW_MS,
  max: 20,
  message,
  standardHeaders: true,
  legacyHeaders: false,
});

// App sessions, per client IP. Generous because many users can share one NAT.
const appSessionIpLimiter = rateLimit({
  windowMs: WINDOW_MS,
  max: 100,
  message,
  standardHeaders: true,
  legacyHeaders: false,
});

// App sessions, per account. Must run after validation has set req.sessionUsername
// (the canonical username); requests without one fall back to the client IP.
const appSessionAccountLimiter = rateLimit({
  windowMs: WINDOW_MS,
  max: 10,
  message,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) =>
    req.sessionUsername ? `user:${req.sessionUsername}` : `ip:${ipKeyGenerator(req.ip)}`,
});

module.exports = { authLimiter, appSessionIpLimiter, appSessionAccountLimiter };
