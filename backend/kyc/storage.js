const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');
const { encryptBuffer, decryptBuffer } = require('./crypto');

const STORAGE_KEY_PATTERN = /^[0-9a-f]{64}$/;

// Read at call time so deployments and tests can point it elsewhere.
// This directory must never be served statically.
function storageDir() {
  return process.env.KYC_STORAGE_DIR || path.join(__dirname, '..', 'kyc_storage');
}

function pathFor(storageKey) {
  if (typeof storageKey !== 'string' || !STORAGE_KEY_PATTERN.test(storageKey)) {
    throw new Error('Invalid storage key.');
  }
  return path.join(storageDir(), storageKey);
}

async function saveEncrypted(buf) {
  const sha256 = crypto.createHash('sha256').update(buf).digest('hex');
  const encrypted = encryptBuffer(buf);
  await fs.mkdir(storageDir(), { recursive: true, mode: 0o700 });

  const storageKey = crypto.randomBytes(32).toString('hex');
  const finalPath = pathFor(storageKey);
  const tmpPath = `${finalPath}.tmp`;
  try {
    await fs.writeFile(tmpPath, encrypted, { mode: 0o600, flag: 'wx' });
    await fs.rename(tmpPath, finalPath);
  } catch (err) {
    await fs.rm(tmpPath, { force: true });
    throw err;
  }
  return { storageKey, size: buf.length, sha256 };
}

async function readDecrypted(storageKey) {
  const filePath = pathFor(storageKey);
  return decryptBuffer(await fs.readFile(filePath));
}

async function deleteStored(storageKey) {
  const filePath = pathFor(storageKey);
  await fs.rm(filePath, { force: true });
}

module.exports = { saveEncrypted, readDecrypted, deleteStored };
