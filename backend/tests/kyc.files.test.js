const fs = require('fs');
const path = require('path');
const {
  kycKeyAvailable,
  encryptBuffer,
  decryptBuffer,
  encryptField,
  decryptField,
  maskId,
} = require('../kyc/crypto');
const { sniffType, stripMetadata } = require('../kyc/files');
const { saveEncrypted, readDecrypted, deleteStored } = require('../kyc/storage');

const TINY_PNG = fs.readFileSync(path.join(__dirname, 'fixtures', 'tiny.png'));

function pngChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  // CRC value is not validated by stripMetadata; zeros are fine for the test.
  return Buffer.concat([len, Buffer.from(type, 'ascii'), data, Buffer.alloc(4)]);
}

function jpegSegment(marker, payload) {
  const len = Buffer.alloc(2);
  len.writeUInt16BE(payload.length + 2);
  return Buffer.concat([Buffer.from([0xff, marker]), len, payload]);
}

describe('kyc crypto', () => {
  test('encrypt/decrypt round trip', () => {
    const plain = Buffer.from('national id scan bytes');
    const enc = encryptBuffer(plain);
    expect(enc.length).toBe(12 + 16 + plain.length);
    expect(decryptBuffer(enc).equals(plain)).toBe(true);
    expect(decryptField(encryptField('63-1234567-A-89'))).toBe('63-1234567-A-89');
    expect(decryptField(encryptField(''))).toBe('');
    expect(encryptField(null)).toBeNull();
    expect(encryptField(undefined)).toBeNull();
  });

  test('decrypt throws when one byte is flipped', () => {
    const enc = encryptBuffer(Buffer.from('secret payload'));
    for (const i of [0, 12, enc.length - 1]) {
      const bad = Buffer.from(enc);
      bad[i] ^= 0x01;
      expect(() => decryptBuffer(bad)).toThrow();
    }
  });

  test('two encryptions of the same input differ', () => {
    const plain = Buffer.from('same input');
    expect(encryptBuffer(plain).equals(encryptBuffer(plain))).toBe(false);
    expect(encryptField('same')).not.toBe(encryptField('same'));
  });

  test('kycKeyAvailable false for missing or 31-byte key', () => {
    const original = process.env.KYC_ENCRYPTION_KEY;
    try {
      expect(kycKeyAvailable()).toBe(true);
      delete process.env.KYC_ENCRYPTION_KEY;
      expect(kycKeyAvailable()).toBe(false);
      process.env.KYC_ENCRYPTION_KEY = Buffer.alloc(31, 7).toString('base64');
      expect(kycKeyAvailable()).toBe(false);
      expect(() => encryptBuffer(Buffer.from('x'))).toThrow();
    } finally {
      process.env.KYC_ENCRYPTION_KEY = original;
    }
  });

  test('maskId shows only the last 4 characters', () => {
    expect(maskId('63-1234567-A-89')).toBe('•••• A-89');
    expect(maskId('abc')).toBe('••••');
  });
});

describe('kyc files', () => {
  test('sniffType detects by magic bytes', () => {
    expect(sniffType(TINY_PNG)).toBe('image/png');
    expect(sniffType(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]))).toBe('image/jpeg');
    expect(sniffType(Buffer.from('%PDF-1.4\n'))).toBe('application/pdf');
    expect(sniffType(Buffer.from('<html></html>'))).toBeNull();
    expect(sniffType(Buffer.alloc(0))).toBeNull();
  });

  test('stripMetadata removes JPEG APP1 and keeps other segments', () => {
    const app0 = jpegSegment(0xe0, Buffer.from('JFIF\0\x01\x01\0\0\x01\0\x01\0\0', 'binary'));
    const app1 = jpegSegment(
      0xe1,
      Buffer.concat([Buffer.from('Exif\0\0', 'binary'), Buffer.from('GPS-LAT-17.8292-LON-31.0522')]),
    );
    const dqt = jpegSegment(0xdb, Buffer.alloc(65, 1));
    const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8]), app0, app1, dqt, Buffer.from([0xff, 0xd9])]);

    const out = stripMetadata(jpeg, 'image/jpeg');
    expect(out.includes(Buffer.from('Exif'))).toBe(false);
    expect(out.includes(Buffer.from('GPS'))).toBe(false);
    expect(out.includes(app0)).toBe(true);
    expect(out.includes(dqt)).toBe(true);
    expect(out.subarray(0, 2).equals(Buffer.from([0xff, 0xd8]))).toBe(true);
    expect(out.subarray(-2).equals(Buffer.from([0xff, 0xd9]))).toBe(true);
  });

  test('stripMetadata keeps JPEG scan data after SOS verbatim', () => {
    const sos = jpegSegment(0xda, Buffer.from([1, 1, 0, 0, 0x3f, 0]));
    const scan = Buffer.from([0x12, 0xff, 0x00, 0xff, 0xe1, 0x34]); // looks like APP1 but is entropy data
    const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8]), sos, scan, Buffer.from([0xff, 0xd9])]);
    expect(stripMetadata(jpeg, 'image/jpeg').equals(jpeg)).toBe(true);
  });

  test('stripMetadata rejects malformed JPEG', () => {
    const truncated = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x40, 0x01]);
    expect(() => stripMetadata(truncated, 'image/jpeg')).toThrow('Unreadable image file.');
    const badMarker = Buffer.from([0xff, 0xd8, 0x00, 0x11, 0x22]);
    expect(() => stripMetadata(badMarker, 'image/jpeg')).toThrow('Unreadable image file.');
  });

  test('stripMetadata removes PNG eXIf chunk', () => {
    const exif = pngChunk('eXIf', Buffer.from('MM\0*GPS-DATA'));
    const ihdrEnd = 8 + 25; // signature + IHDR chunk
    const withExif = Buffer.concat([TINY_PNG.subarray(0, ihdrEnd), exif, TINY_PNG.subarray(ihdrEnd)]);

    const out = stripMetadata(withExif, 'image/png');
    expect(out.includes(Buffer.from('eXIf'))).toBe(false);
    expect(out.equals(TINY_PNG)).toBe(true);
    for (const type of ['IHDR', 'IDAT', 'IEND']) {
      expect(out.includes(Buffer.from(type))).toBe(true);
    }
  });

  test('stripMetadata rejects malformed PNG', () => {
    expect(() => stripMetadata(TINY_PNG.subarray(0, 20), 'image/png')).toThrow('Unreadable image file.');
  });

  test('stripMetadata leaves PDF unchanged', () => {
    const pdf = Buffer.from('%PDF-1.4\n%%EOF');
    expect(stripMetadata(pdf, 'application/pdf').equals(pdf)).toBe(true);
  });
});

describe('kyc storage', () => {
  test('saveEncrypted writes ciphertext only', async () => {
    const plain = Buffer.from('PLAINTEXT-ID-SCAN-63-1234567-A-89');
    const { storageKey, size, sha256 } = await saveEncrypted(plain);
    expect(storageKey).toMatch(/^[0-9a-f]{64}$/);
    expect(size).toBe(plain.length);
    expect(sha256).toBe(require('crypto').createHash('sha256').update(plain).digest('hex'));

    const filePath = path.join(process.env.KYC_STORAGE_DIR, storageKey);
    const onDisk = fs.readFileSync(filePath);
    expect(onDisk.includes(plain)).toBe(false);
    expect(onDisk.includes(Buffer.from('PLAINTEXT'))).toBe(false);
    expect(fs.statSync(filePath).mode & 0o777).toBe(0o600);

    expect((await readDecrypted(storageKey)).equals(plain)).toBe(true);

    await deleteStored(storageKey);
    expect(fs.existsSync(filePath)).toBe(false);
  });

  test('readDecrypted rejects ../x and non-hex keys', async () => {
    await expect(readDecrypted('../x')).rejects.toThrow();
    await expect(readDecrypted('z'.repeat(64))).rejects.toThrow();
    await expect(readDecrypted('A'.repeat(64))).rejects.toThrow();
    await expect(deleteStored('../x')).rejects.toThrow();
  });
});
