const crypto = require('crypto');

const IV_LENGTH = 12;
const TAG_LENGTH = 16;
const KEY_LENGTH = 32;

// Read at call time so the key can change in the environment (and in tests).
function loadKey() {
  const raw = process.env.KYC_ENCRYPTION_KEY;
  if (!raw) return null;
  const key = Buffer.from(raw, 'base64');
  return key.length === KEY_LENGTH ? key : null;
}

function kycKeyAvailable() {
  return loadKey() !== null;
}

function requireKey() {
  const key = loadKey();
  if (!key) throw new Error('KYC encryption key is not configured.');
  return key;
}

// Layout: 12-byte IV || 16-byte GCM tag || ciphertext.
function encryptBuffer(buf) {
  const key = requireKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv, { authTagLength: TAG_LENGTH });
  const ciphertext = Buffer.concat([cipher.update(buf), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]);
}

function decryptBuffer(buf) {
  const key = requireKey();
  if (!Buffer.isBuffer(buf) || buf.length < IV_LENGTH + TAG_LENGTH) {
    throw new Error('Encrypted payload is too short.');
  }
  const iv = buf.subarray(0, IV_LENGTH);
  const tag = buf.subarray(IV_LENGTH, IV_LENGTH + TAG_LENGTH);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv, { authTagLength: TAG_LENGTH });
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(buf.subarray(IV_LENGTH + TAG_LENGTH)), decipher.final()]);
}

function encryptField(str) {
  if (str === null || str === undefined) return null;
  return encryptBuffer(Buffer.from(String(str), 'utf8')).toString('base64');
}

function decryptField(str) {
  if (str === null || str === undefined) return null;
  return decryptBuffer(Buffer.from(str, 'base64')).toString('utf8');
}

function maskId(str) {
  const value = str === null || str === undefined ? '' : String(str);
  if (value.length < 4) return '••••';
  return `•••• ${value.slice(-4)}`;
}

module.exports = {
  kycKeyAvailable,
  encryptBuffer,
  decryptBuffer,
  encryptField,
  decryptField,
  maskId,
};
