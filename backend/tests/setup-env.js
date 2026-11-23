const fs = require('fs');
const os = require('os');
const path = require('path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-only-jwt-secret';
// Test-only KYC key: 32 bytes of 0x42. Never use outside tests.
process.env.KYC_ENCRYPTION_KEY =
  process.env.KYC_ENCRYPTION_KEY || Buffer.alloc(32, 0x42).toString('base64');
process.env.KYC_STORAGE_DIR =
  process.env.KYC_STORAGE_DIR || fs.mkdtempSync(path.join(os.tmpdir(), 'kyc-test-'));
