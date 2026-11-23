const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createAppUserWithToken } = require('./helpers/app_user');

const TINY_PNG = fs.readFileSync(path.join(__dirname, 'fixtures', 'tiny.png'));
const DAY = 86400000;
const ROLLOUT = new Date('2026-01-01T00:00:00Z');
const ID_NUMBER = '63-1234567-X-42';

let mongoServer;
let app;
let AppUser;
let KycSettings;
let KycDraft;
let KycDocument;
let KycSubmission;
let KycEvent;
let storage;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  AppUser = require('../models/app_user.model');
  KycSettings = require('../kyc/models/kyc_settings.model');
  KycDraft = require('../kyc/models/kyc_draft.model');
  KycDocument = require('../kyc/models/kyc_document.model');
  KycSubmission = require('../kyc/models/kyc_submission.model');
  KycEvent = require('../kyc/models/kyc_event.model');
  storage = require('../kyc/storage');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  await KycSettings.create({ rolloutAt: ROLLOUT });
});

afterEach(async () => {
  delete process.env.LEGACY_USERID_ROUTES;
  delete process.env.KYC_MAX_UPLOAD_MB;
  delete process.env.KYC_REQUIRE_PROOF_OF_RESIDENCE;
  await Promise.all([
    AppUser.deleteMany({}),
    KycDraft.deleteMany({}),
    KycDocument.deleteMany({}),
    KycSubmission.deleteMany({}),
    KycEvent.deleteMany({}),
  ]);
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

let phoneSeq = 0;
const newUser = (opts = {}) => {
  phoneSeq += 1;
  return createAppUserWithToken({
    sipUsername: `+26377100${String(phoneSeq).padStart(4, '0')}`,
    ...opts,
  });
};

const auth = (token) => ({ Authorization: `Bearer ${token}` });

const completeData = (overrides = {}) => ({
  personal: {
    firstName: 'Tendai',
    lastName: 'Moyo',
    dateOfBirth: '1990-05-14',
    gender: 'female',
    nationality: 'Zimbabwean',
  },
  address: { line1: '12 Samora Machel Ave', city: 'Harare', country: 'Zimbabwe' },
  identification: { idType: 'national_id', idNumber: ID_NUMBER },
  ...overrides,
});

const pngChunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  return Buffer.concat([len, Buffer.from(type, 'ascii'), data, Buffer.alloc(4)]);
};

const upload = (token, kind, buf = TINY_PNG, filename = 'id.png', contentType = 'image/png') =>
  request(app)
    .post('/api/kyc/documents')
    .set(auth(token))
    .field('kind', kind)
    .attach('file', buf, { filename, contentType });

const saveDraft = (token, data) =>
  request(app).put('/api/kyc/draft').set(auth(token)).send({ data });

const futureDate = (days) => new Date(Date.now() + days * DAY).toISOString().slice(0, 10);

describe('auth and availability', () => {
  test('legacy request (no token, LEGACY on) to /api/kyc/me is 401', async () => {
    process.env.LEGACY_USERID_ROUTES = 'true';
    const res = await request(app).get('/api/kyc/me').query({ userId: '+263771009999' });
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ message: 'Sign in required.' });
  });

  test('no token is 401', async () => {
    const res = await request(app).get('/api/kyc/me');
    expect(res.status).toBe(401);
  });

  test('valid token whose AppUser row is missing is 401', async () => {
    const { appUser, token } = await newUser();
    await AppUser.deleteOne({ _id: appUser._id });
    const res = await request(app).get('/api/kyc/me').set(auth(token));
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ message: 'Sign in required.' });
  });

  test('503 when KYC_ENCRYPTION_KEY is missing', async () => {
    const { token } = await newUser();
    const saved = process.env.KYC_ENCRYPTION_KEY;
    delete process.env.KYC_ENCRYPTION_KEY;
    try {
      const res = await request(app).get('/api/kyc/me').set(auth(token));
      expect(res.status).toBe(503);
      expect(res.body).toEqual({ message: 'KYC is temporarily unavailable.' });
    } finally {
      process.env.KYC_ENCRYPTION_KEY = saved;
    }
  });
});

describe('GET /api/kyc/me', () => {
  test('GET /me for a new user returns NOT_STARTED, progress 0, a deadline 60 days after clock start', async () => {
    // After ROLLOUT, so the clock starts at createdAt; recent enough not to be restricted.
    const createdAt = new Date(Math.floor((Date.now() - 5 * DAY) / 1000) * 1000);
    const { token, appUser } = await newUser({ createdAt });
    const res = await request(app).get('/api/kyc/me').set(auth(token));
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('NOT_STARTED');
    expect(res.body.underlyingStatus).toBe('NOT_STARTED');
    expect(res.body.progress).toBe(0);
    expect(new Date(res.body.deadline).getTime()).toBe(createdAt.getTime() + 60 * DAY);
    expect(res.body.draft).toBeNull();
    expect(res.body.documents).toEqual([]);
    expect(res.body.history).toEqual([]);
    expect(res.body.phone).toBe(appUser.sipUsername);
    expect(res.body.outstanding).toEqual(
      expect.arrayContaining(['personal.firstName', 'address.city', 'identification.idNumber'])
    );
  });
});

describe('PUT /api/kyc/draft', () => {
  test('saving a draft moves NOT_STARTED to IN_PROGRESS and resumes on GET /me', async () => {
    const { token, appUser } = await newUser();
    const data = completeData();
    delete data.address;
    const put = await saveDraft(token, data);
    expect(put.status).toBe(200);

    const user = await AppUser.findById(appUser._id);
    expect(user.kyc.status).toBe('IN_PROGRESS');
    expect(user.kyc.startedAt).toBeInstanceOf(Date);

    const res = await request(app).get('/api/kyc/me').set(auth(token));
    expect(res.body.status).toBe('IN_PROGRESS');
    expect(res.body.draft.personal.firstName).toBe('Tendai');
    expect(res.body.draft.identification.idType).toBe('national_id');
    expect(res.body.draft.identification.idNumberMasked).toBe('•••• X-42');
    expect(res.body.draft.identification.idNumber).toBeUndefined();
    expect(res.body.progress).toBe(40);
    expect(res.body.outstanding).toEqual(
      expect.arrayContaining(['address.line1', 'address.city', 'documents.id_front', 'documents.id_back'])
    );
    expect(res.body.outstanding).not.toContain('personal.firstName');

    const events = await KycEvent.find({ appUserId: appUser._id, type: 'DRAFT_SAVED' });
    expect(events).toHaveLength(1);
    await saveDraft(token, { address: { city: 'Bulawayo' } });
    expect(await KycEvent.countDocuments({ type: 'DRAFT_SAVED' })).toBe(1);
  });

  test('ID number is stored encrypted and kept when a later save omits it', async () => {
    const { token, appUser } = await newUser();
    await saveDraft(token, completeData());
    await saveDraft(token, { personal: { firstName: 'Rudo' } });
    const raw = await KycDraft.collection.findOne({ appUserId: appUser._id });
    const json = JSON.stringify(raw);
    expect(json).not.toContain(ID_NUMBER);
    expect(json).not.toContain('1234567');
    expect(raw.data.identification.idNumber).toBeUndefined();
    expect(typeof raw.data.identification.idNumberEnc).toBe('string');
    expect(raw.data.personal.firstName).toBe('Rudo');
    expect(raw.data.personal.lastName).toBe('Moyo');
  });

  test('draft with wrong types or overlong values is 400', async () => {
    const { token } = await newUser();
    const res = await saveDraft(token, { personal: { firstName: 'x'.repeat(61), lastName: 5 } });
    expect(res.status).toBe(400);
    expect(res.body.errors['personal.firstName']).toBeDefined();
    expect(res.body.errors['personal.lastName']).toBeDefined();
    const bad = await request(app).put('/api/kyc/draft').set(auth(token)).send({ data: 'nope' });
    expect(bad.status).toBe(400);
  });

  test('draft is 409 once submitted', async () => {
    const { token } = await newUser({ kyc: { status: 'PENDING_REVIEW' } });
    const res = await saveDraft(token, completeData());
    expect(res.status).toBe(409);
    expect(res.body).toEqual({ message: 'Your KYC is already submitted.' });
  });
});

describe('documents', () => {
  test('upload accepts a real PNG, returns metadata, and the stored file is encrypted', async () => {
    const { token, appUser } = await newUser();
    const res = await upload(token, 'id_front');
    expect(res.status).toBe(201);
    expect(res.body).toEqual({
      id: expect.any(String),
      kind: 'id_front',
      mime: 'image/png',
      size: TINY_PNG.length,
      createdAt: expect.any(String),
    });
    const doc = await KycDocument.findById(res.body.id);
    expect(String(doc.appUserId)).toBe(String(appUser._id));
    expect(doc.submissionId).toBeNull();
    const onDisk = fs.readFileSync(path.join(process.env.KYC_STORAGE_DIR, doc.storageKey));
    expect(onDisk.includes(Buffer.from('IHDR'))).toBe(false);
    expect(onDisk.equals(TINY_PNG)).toBe(false);
    expect((await storage.readDecrypted(doc.storageKey)).equals(TINY_PNG)).toBe(true);
    expect(await KycEvent.countDocuments({ appUserId: appUser._id, type: 'DOCUMENT_UPLOADED' })).toBe(1);

    const get = await request(app)
      .get(`/api/kyc/documents/${res.body.id}`)
      .set(auth(token))
      .buffer(true)
      .parse((r, cb) => {
        const chunks = [];
        r.on('data', (c) => chunks.push(c));
        r.on('end', () => cb(null, Buffer.concat(chunks)));
      });
    expect(get.status).toBe(200);
    expect(get.headers['content-type']).toMatch(/^image\/png/);
    expect(get.headers['cache-control']).toBe('no-store');
    expect(get.headers['content-disposition']).toBe('inline');
    expect(Buffer.from(get.body).equals(TINY_PNG)).toBe(true);
  });

  test('upload strips metadata before hashing and storing, and stores the sniffed mime', async () => {
    const { token } = await newUser();
    const ihdrEnd = 8 + 25;
    const withText = Buffer.concat([
      TINY_PNG.subarray(0, ihdrEnd),
      pngChunk('tEXt', Buffer.from('Comment\0TEXT-SECRET', 'binary')),
      TINY_PNG.subarray(ihdrEnd),
    ]);
    const res = await upload(token, 'id_front', withText, 'id.jpg', 'image/jpeg');
    expect(res.status).toBe(201);
    expect(res.body.mime).toBe('image/png');
    expect(res.body.size).toBe(TINY_PNG.length);
    const doc = await KycDocument.findById(res.body.id);
    expect(doc.mime).toBe('image/png');
    expect(doc.sha256).toBe(crypto.createHash('sha256').update(TINY_PNG).digest('hex'));
    const plain = await storage.readDecrypted(doc.storageKey);
    expect(plain.includes(Buffer.from('tEXt'))).toBe(false);
    expect(plain.includes(Buffer.from('TEXT-SECRET'))).toBe(false);
  });

  test('upload rejects HTML bytes sent as image/jpeg with 415', async () => {
    const { token } = await newUser();
    const html = Buffer.from('<html><script>alert(1)</script></html>');
    const res = await upload(token, 'id_front', html, 'id.jpg', 'image/jpeg');
    expect(res.status).toBe(415);
    expect(res.body).toEqual({ message: 'Upload a JPEG, PNG or PDF file.' });
    expect(await KycDocument.countDocuments()).toBe(0);
  });

  test('upload rejects a malformed JPEG with 415', async () => {
    const { token } = await newUser();
    const bad = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x40, 0x01]);
    const res = await upload(token, 'id_front', bad, 'id.jpg', 'image/jpeg');
    expect(res.status).toBe(415);
    expect(res.body).toEqual({ message: 'Upload a JPEG, PNG or PDF file.' });
  });

  test('upload rejects oversize with 413', async () => {
    process.env.KYC_MAX_UPLOAD_MB = '0.001';
    const { token } = await newUser();
    const big = Buffer.concat([TINY_PNG, Buffer.alloc(5000)]);
    const res = await upload(token, 'id_front', big);
    expect(res.status).toBe(413);
    expect(res.body).toEqual({ message: 'File is too large.' });
    expect(await KycDocument.countDocuments()).toBe(0);
  });

  test('upload rejects an unknown kind with 400', async () => {
    const { token } = await newUser();
    const res = await upload(token, 'selfie');
    expect(res.status).toBe(400);
    expect(await KycDocument.countDocuments()).toBe(0);
  });

  test('a second upload of the same kind replaces the first and deletes its file', async () => {
    const { token, appUser } = await newUser();
    const first = await upload(token, 'id_front');
    const oldKey = (await KycDocument.findById(first.body.id)).storageKey;
    const second = await upload(token, 'id_front');
    expect(second.status).toBe(201);
    const docs = await KycDocument.find({ appUserId: appUser._id });
    expect(docs).toHaveLength(1);
    expect(String(docs[0]._id)).toBe(second.body.id);
    expect(fs.existsSync(path.join(process.env.KYC_STORAGE_DIR, oldKey))).toBe(false);
  });

  test('user B cannot GET or DELETE user A\'s document', async () => {
    const a = await newUser();
    const b = await newUser();
    const up = await upload(a.token, 'id_front');
    const get = await request(app).get(`/api/kyc/documents/${up.body.id}`).set(auth(b.token));
    expect(get.status).toBe(404);
    expect(get.body).toEqual({ message: 'Document not found.' });
    const del = await request(app).delete(`/api/kyc/documents/${up.body.id}`).set(auth(b.token));
    expect(del.status).toBe(404);
    expect(await KycDocument.countDocuments()).toBe(1);

    const own = await request(app).delete(`/api/kyc/documents/${up.body.id}`).set(auth(a.token));
    expect(own.status).toBe(204);
    expect(await KycDocument.countDocuments()).toBe(0);
  });

  test('invalid document ids and missing stored files are 404', async () => {
    const { token } = await newUser();
    const bad = await request(app).get('/api/kyc/documents/not-an-id').set(auth(token));
    expect(bad.status).toBe(404);
    const badDel = await request(app).delete('/api/kyc/documents/not-an-id').set(auth(token));
    expect(badDel.status).toBe(404);

    const up = await upload(token, 'id_front');
    const doc = await KycDocument.findById(up.body.id);
    fs.rmSync(path.join(process.env.KYC_STORAGE_DIR, doc.storageKey));
    const gone = await request(app).get(`/api/kyc/documents/${up.body.id}`).set(auth(token));
    expect(gone.status).toBe(404);
    expect(gone.body).toEqual({ message: 'Document not found.' });
  });

  test('uploads are limited to 30 per hour per user', async () => {
    const { token } = await newUser();
    for (let i = 0; i < 30; i += 1) {
      const res = await upload(token, 'id_front');
      expect(res.status).toBe(201);
    }
    const res = await upload(token, 'id_front');
    expect(res.status).toBe(429);
    expect(res.body).toEqual({ message: 'Too many requests, please try again later.' });
    const other = await newUser();
    expect((await upload(other.token, 'id_front')).status).toBe(201);
  });
});

describe('POST /api/kyc/submit', () => {
  const prepare = async (token, data = completeData(), kinds = ['id_front', 'id_back']) => {
    await saveDraft(token, data);
    for (const kind of kinds) {
      const res = await upload(token, kind);
      expect(res.status).toBe(201);
    }
  };

  test('submit with missing fields returns 400 with field errors', async () => {
    const { token } = await newUser();
    await saveDraft(token, { personal: { firstName: 'Tendai' } });
    const res = await request(app).post('/api/kyc/submit').set(auth(token));
    expect(res.status).toBe(400);
    expect(res.body.message).toBe('Some details are missing or invalid.');
    expect(res.body.errors['personal.lastName']).toBeDefined();
    expect(res.body.errors['address.city']).toBeDefined();
    expect(res.body.errors['identification.idType']).toBeDefined();
    expect(res.body.errors['personal.firstName']).toBeUndefined();
  });

  test('submit with complete data creates PENDING_REVIEW, version 1, links documents, deletes draft', async () => {
    const { token, appUser } = await newUser({
      kyc: { status: 'IN_PROGRESS', restrictedAt: new Date('2026-05-01T00:00:00Z') },
    });
    await prepare(token);
    const res = await request(app).post('/api/kyc/submit').set(auth(token));
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('PENDING_REVIEW');
    expect(res.body.submittedAt).toEqual(expect.any(String));

    const user = await AppUser.findById(appUser._id);
    expect(user.kyc.status).toBe('PENDING_REVIEW');
    expect(user.kyc.submittedAt).toBeInstanceOf(Date);
    expect(user.kyc.restrictedAt).toBeUndefined();

    const subs = await KycSubmission.find({ appUserId: appUser._id });
    expect(subs).toHaveLength(1);
    expect(subs[0].version).toBe(1);
    expect(subs[0].decision).toBe('pending');
    expect(subs[0].phone).toBe(appUser.sipUsername);
    expect(subs[0].personal.firstName).toBe('Tendai');
    expect(JSON.stringify(subs[0].toObject())).not.toContain(ID_NUMBER);
    expect(subs[0].documentIds).toHaveLength(2);
    const docs = await KycDocument.find({ appUserId: appUser._id });
    for (const d of docs) expect(String(d.submissionId)).toBe(String(subs[0]._id));
    expect(await KycDraft.countDocuments({ appUserId: appUser._id })).toBe(0);

    expect(await KycEvent.countDocuments({ appUserId: appUser._id, type: 'SUBMITTED' })).toBe(1);
    expect(await KycEvent.countDocuments({ appUserId: appUser._id, type: 'UNRESTRICTED' })).toBe(1);

    const me = await request(app).get('/api/kyc/me').set(auth(token));
    expect(me.body.status).toBe('PENDING_REVIEW');
    expect(me.body.progress).toBe(100);
    expect(me.body.outstanding).toEqual([]);
    expect(me.body.deadline).toBeNull();
    expect(me.body.history).toEqual([
      expect.objectContaining({ version: 1, decision: 'pending', submittedAt: expect.any(String) }),
    ]);

    // Submitted documents stay readable by their owner.
    const get = await request(app).get(`/api/kyc/documents/${docs[0]._id}`).set(auth(token));
    expect(get.status).toBe(200);
  });

  test('submit twice returns 409', async () => {
    const { token } = await newUser();
    await prepare(token);
    expect((await request(app).post('/api/kyc/submit').set(auth(token))).status).toBe(201);
    const again = await request(app).post('/api/kyc/submit').set(auth(token));
    expect(again.status).toBe(409);
    expect(again.body).toEqual({ message: 'Your KYC is already submitted.' });
    expect(await KycSubmission.countDocuments()).toBe(1);
  });

  test('national id requires front and back; passport requires bio page and future expiry', async () => {
    const nat = await newUser();
    await prepare(nat.token, completeData(), ['id_front']);
    const natRes = await request(app).post('/api/kyc/submit').set(auth(nat.token));
    expect(natRes.status).toBe(400);
    expect(natRes.body.errors['documents.id_back']).toBeDefined();
    expect(natRes.body.errors['documents.id_front']).toBeUndefined();

    const pass = await newUser();
    const passport = completeData({
      identification: { idType: 'passport', idNumber: 'FN123456', idExpiry: '2020-01-01' },
    });
    await prepare(pass.token, passport, ['id_front', 'id_back']);
    const passRes = await request(app).post('/api/kyc/submit').set(auth(pass.token));
    expect(passRes.status).toBe(400);
    expect(passRes.body.errors['documents.passport_bio']).toBeDefined();
    expect(passRes.body.errors['identification.idExpiry']).toBeDefined();

    await saveDraft(pass.token, { identification: { idExpiry: futureDate(365) } });
    await upload(pass.token, 'passport_bio');
    const ok = await request(app).post('/api/kyc/submit').set(auth(pass.token));
    expect(ok.status).toBe(201);
  });

  test('proof of residence is required only when configured', async () => {
    process.env.KYC_REQUIRE_PROOF_OF_RESIDENCE = 'true';
    const { token } = await newUser();
    await prepare(token);
    const res = await request(app).post('/api/kyc/submit').set(auth(token));
    expect(res.status).toBe(400);
    expect(res.body.errors['documents.proof_of_residence']).toBeDefined();
  });

  test('invalid national id number and underage date of birth are rejected', async () => {
    const { token } = await newUser();
    const data = completeData();
    data.identification.idNumber = '12345';
    data.personal.dateOfBirth = futureDate(-365 * 10);
    await prepare(token, data);
    const res = await request(app).post('/api/kyc/submit').set(auth(token));
    expect(res.status).toBe(400);
    expect(res.body.errors['identification.idNumber']).toBeDefined();
    expect(res.body.errors['personal.dateOfBirth']).toBeDefined();
  });

  test('GET /me never returns the raw ID number', async () => {
    const { token } = await newUser();
    await prepare(token);
    const digits = ID_NUMBER.replace(/-/g, '');
    const before = await request(app).get('/api/kyc/me').set(auth(token));
    expect(before.status).toBe(200);
    expect(JSON.stringify(before.body)).not.toContain(ID_NUMBER);
    expect(JSON.stringify(before.body)).not.toContain(digits);
    expect(JSON.stringify(before.body)).not.toContain('1234567');
    await request(app).post('/api/kyc/submit').set(auth(token));
    const after = await request(app).get('/api/kyc/me').set(auth(token));
    expect(JSON.stringify(after.body)).not.toContain(ID_NUMBER);
    expect(JSON.stringify(after.body)).not.toContain('1234567');
  });
});
