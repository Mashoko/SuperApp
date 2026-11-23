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

// KYC document uploads, per signed-in user. Must run after resolveUser has set req.userId;
// requests without one fall back to the client IP.
const kycUploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 30,
  message,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => (req.userId ? `user:${req.userId}` : `ip:${ipKeyGenerator(req.ip)}`),
});

// KYC draft saves and submits, per signed-in user (one shared bucket). Must run after
// resolveUser has set req.userId; requests without one fall back to the client IP.
const kycWriteLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 60,
  message,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => (req.userId ? `user:${req.userId}` : `ip:${ipKeyGenerator(req.ip)}`),
});

module.exports = {
  authLimiter,
  appSessionIpLimiter,
  appSessionAccountLimiter,
  kycUploadLimiter,
  kycWriteLimiter,
};
