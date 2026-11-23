const fs = require('fs');
const path = require('path');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createAppUserWithToken } = require('./helpers/app_user');
const { signAdminToken } = require('../middleware/auth.middleware');

const TINY_PNG = fs.readFileSync(path.join(__dirname, 'fixtures', 'tiny.png'));
const DAY = 86400000;
const HOUR = 3600000;
const ROLLOUT = new Date('2026-01-01T00:00:00Z');
const ID_NUMBER = '63-1234567-X-42';
const BASE = '/api/admin/kyc';

let mongoServer;
let app;
let AppUser;
let KycSettings;
let KycDraft;
let KycDocument;
let KycSubmission;
let KycEvent;
let Notification;

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
  Notification = require('../kyc/models/notification.model');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  await KycSettings.create({ rolloutAt: ROLLOUT });
});

afterEach(async () => {
  await KycSettings.updateOne(
    {},
    {
      $set: {
        firstNudgeDays: 1,
        secondNudgeDays: 7,
        reminderIntervalDays: 14,
        warningBeforeDays: 4,
        enforcementDays: 60,
        resubmitGraceDays: 14,
        remindersEnabled: true,
      },
    }
  );
  const names = [
    'appusers',
    'kycevents',
    'kycdrafts',
    'kycdocuments',
    'kycsubmissions',
    'notifications',
    'carts',
  ];
  await Promise.all(names.map((n) => mongoose.connection.collection(n).deleteMany({})));
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

const staffToken = (role, username = `${role}_1`) =>
  signAdminToken({ _id: new mongoose.Types.ObjectId(), role, username });
const reviewer = () => ({ Authorization: `Bearer ${staffToken('kyc_reviewer', 'rudo.reviewer')}` });
const superAdmin = () => ({ Authorization: `Bearer ${staffToken('super_admin', 'chipo.admin')}` });
const auth = (token) => ({ Authorization: `Bearer ${token}` });

let phoneSeq = 0;
const daysAgo = (days) => new Date(Math.floor((Date.now() - days * DAY) / 1000) * 1000);
const newUser = (opts = {}) => {
  phoneSeq += 1;
  return createAppUserWithToken({
    sipUsername: `+26377500${String(phoneSeq).padStart(4, '0')}`,
    ...opts,
  });
};
const pastDeadlineUser = (opts = {}) => newUser({ createdAt: daysAgo(70), ...opts });

const completeData = () => ({
  personal: {
    firstName: 'Tendai',
    lastName: 'Moyo',
    dateOfBirth: '1990-05-14',
    gender: 'female',
    nationality: 'Zimbabwean',
  },
  address: { line1: '12 Samora Machel Ave', city: 'Harare', country: 'Zimbabwe' },
  identification: { idType: 'national_id', idNumber: ID_NUMBER },
});

const saveDraft = (token, data) =>
  request(app).put('/api/kyc/draft').set(auth(token)).send({ data });
const uploadDoc = (token, kind) =>
  request(app)
    .post('/api/kyc/documents')
    .set(auth(token))
    .field('kind', kind)
    .attach('file', TINY_PNG, { filename: 'id.png', contentType: 'image/png' });
const uploadDocs = async (token) => {
  expect((await uploadDoc(token, 'id_front')).status).toBe(201);
  expect((await uploadDoc(token, 'id_back')).status).toBe(201);
};
const submitKyc = async (token) => {
  expect((await saveDraft(token, completeData())).status).toBe(200);
  await uploadDocs(token);
  const res = await request(app).post('/api/kyc/submit').set(auth(token));
  expect(res.status).toBe(201);
  return res;
};
const submittedUser = async (opts) => {
  const created = await newUser(opts);
  await submitKyc(created.token);
  return created;
};

const post = (url, headers, body) => request(app).post(`${BASE}${url}`).set(headers).send(body);
const get = (url, headers) => request(app).get(`${BASE}${url}`).set(headers);

describe('access control', () => {
  test('kyc_reviewer and super_admin can list; staff and app tokens cannot', async () => {
    const { token } = await newUser();
    expect((await get('/users', reviewer())).status).toBe(200);
    expect((await get('/users', superAdmin())).status).toBe(200);
    expect((await get('/users', auth(staffToken('staff')))).status).toBe(403);
    expect((await get('/users', auth(staffToken('shop_manager')))).status).toBe(403);
    expect((await get('/users', auth(token))).status).toBe(401);
    expect((await request(app).get(`${BASE}/users`)).status).toBe(401);
  });
});

describe('stats and search', () => {
  test('stats count each status and restricted users', async () => {
    await newUser();
    await newUser({ kyc: { status: 'IN_PROGRESS' } });
    await pastDeadlineUser({ kyc: { status: 'IN_PROGRESS' } });
    await pastDeadlineUser();
    await newUser({ kyc: { status: 'PENDING_REVIEW' } });
    await newUser({ kyc: { status: 'APPROVED' } });
    await pastDeadlineUser({ kyc: { status: 'APPROVED' } });
    await newUser({ kyc: { status: 'REJECTED', cycle: 1, cycleStartedAt: daysAgo(1) } });
    await newUser({ kyc: { status: 'REQUIRES_CORRECTION', cycle: 1, cycleStartedAt: daysAgo(20) } });
    await newUser({ kyc: { status: 'EXPIRED', cycle: 1, cycleStartedAt: daysAgo(2) } });
    // A row with no kyc subdocument counts as NOT_STARTED.
    await AppUser.collection.insertOne({ sipUsername: '+263775999999', createdAt: daysAgo(3) });

    const res = await get('/stats', reviewer());
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      total: 11,
      approved: 2,
      notStarted: 3,
      inProgress: 2,
      pendingReview: 1,
      rejected: 1,
      requiresCorrection: 1,
      expired: 1,
      restricted: 3,
    });
  });

  test('search by partial username and filter by RESTRICTED', async () => {
    const a = await newUser();
    const b = await pastDeadlineUser();
    await AppUser.updateOne({ _id: a.appUser._id }, { $set: { displayName: 'Tatenda (Shop)' } });

    const byName = await get(`/users?q=${encodeURIComponent('tatenda (s')}`, reviewer());
    expect(byName.status).toBe(200);
    expect(byName.body.items.map((i) => i.id)).toEqual([String(a.appUser._id)]);

    const partial = a.appUser.sipUsername.slice(4, 10);
    const byPhone = await get(`/users?q=${encodeURIComponent(partial)}`, reviewer());
    expect(byPhone.body.items.map((i) => i.id)).toContain(String(a.appUser._id));

    const restricted = await get('/users?status=RESTRICTED', reviewer());
    expect(restricted.status).toBe(200);
    expect(restricted.body.total).toBe(1);
    expect(restricted.body.totalPages).toBe(1);
    expect(restricted.body.page).toBe(1);
    const [row] = restricted.body.items;
    expect(row).toMatchObject({
      id: String(b.appUser._id),
      username: b.appUser.sipUsername,
      status: 'RESTRICTED',
      underlyingStatus: 'NOT_STARTED',
      submittedAt: null,
    });
    expect(new Date(row.deadline).getTime()).toBe(b.appUser.createdAt.getTime() + 60 * DAY);

    const notStarted = await get('/users?status=NOT_STARTED&limit=1', reviewer());
    expect(notStarted.body.total).toBe(2);
    expect(notStarted.body.items).toHaveLength(1);
    expect(notStarted.body.totalPages).toBe(2);

    expect((await get('/users?status=BOGUS', reviewer())).status).toBe(400);
    expect((await get(`/users?q=${'a'.repeat(65)}`, reviewer())).status).toBe(400);
  });
});

describe('decisions', () => {
  test('approve restores access to a restricted user who had submitted', async () => {
    const { appUser, token } = await pastDeadlineUser();
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(403);
    await submitKyc(token);

    const res = await post(`/users/${appUser._id}/approve`, reviewer());
    expect(res.status).toBe(200);
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(200);

    const updated = await AppUser.findById(appUser._id);
    expect(updated.kyc.status).toBe('APPROVED');
    expect(updated.kyc.verifiedAt).toBeInstanceOf(Date);
    expect(updated.kyc.reviewedBy).toBe('rudo.reviewer');
    const sub = await KycSubmission.findOne({ appUserId: appUser._id });
    expect(sub.decision).toBe('approved');
    expect(sub.decidedBy).toBe('rudo.reviewer');
    const event = await KycEvent.findOne({ appUserId: appUser._id, type: 'APPROVED' });
    expect(event.actor).toBe('rudo.reviewer');
    expect(await Notification.countDocuments({ appUserId: appUser._id, kind: 'APPROVED' })).toBe(1);
  });

  test('approve requires PENDING_REVIEW', async () => {
    const { appUser } = await newUser({ kyc: { status: 'IN_PROGRESS' } });
    const res = await post(`/users/${appUser._id}/approve`, reviewer());
    expect(res.status).toBe(409);
    const missing = await post(`/users/${new mongoose.Types.ObjectId()}/approve`, reviewer());
    expect(missing.status).toBe(404);
  });

  test('reject requires a reason, starts a new cycle, user can edit draft and resubmit as version 2', async () => {
    const { appUser, token } = await submittedUser();

    expect((await post(`/users/${appUser._id}/reject`, reviewer(), {})).status).toBe(400);
    const short = await post(`/users/${appUser._id}/reject`, reviewer(), { reason: ' abc. ' });
    expect(short.status).toBe(400);
    expect(short.body).toEqual({ message: 'Give a reason between 5 and 500 characters.' });

    const before = Date.now();
    const res = await post(`/users/${appUser._id}/reject`, reviewer(), {
      reason: '  The ID photo is blurred.  ',
    });
    expect(res.status).toBe(200);

    const updated = await AppUser.findById(appUser._id);
    expect(updated.kyc.status).toBe('REJECTED');
    expect(updated.kyc.rejectionReason).toBe('The ID photo is blurred');
    expect(updated.kyc.cycle).toBe(1);
    expect(updated.kyc.cycleStartedAt.getTime()).toBeGreaterThanOrEqual(before);
    expect(updated.kyc.lastReminderStage).toBeNull();
    const sub = await KycSubmission.findOne({ appUserId: appUser._id });
    expect(sub.decision).toBe('rejected');
    expect(sub.reason).toBe('The ID photo is blurred');
    const event = await KycEvent.findOne({ appUserId: appUser._id, type: 'REJECTED' });
    expect(event.actor).toBe('rudo.reviewer');
    const note = await Notification.findOne({ appUserId: appUser._id, kind: 'REJECTED' });
    expect(note.body).toContain('Reason: The ID photo is blurred.');

    // Second reviewer action on the same submission loses.
    const again = await post(`/users/${appUser._id}/reject`, reviewer(), { reason: 'Second try here' });
    expect(again.status).toBe(409);

    // The draft is seeded from the submission, so only documents need re-uploading.
    const me = await request(app).get('/api/kyc/me').set(auth(token));
    expect(me.body.draft.personal.firstName).toBe('Tendai');
    expect(me.body.draft.identification.idNumberMasked).toBe('•••• X-42');
    expect(me.body.rejectionReason).toBe('The ID photo is blurred');
    const edit = await saveDraft(token, { address: { city: 'Bulawayo' } });
    expect(edit.status).toBe(200);
    await uploadDocs(token);
    const resubmit = await request(app).post('/api/kyc/submit').set(auth(token));
    expect(resubmit.status).toBe(201);
    const v2 = await KycSubmission.findOne({ appUserId: appUser._id, version: 2 });
    expect(v2.address.city).toBe('Bulawayo');
    expect(v2.identification.idNumberEnc).toBeTruthy();
  });

  test('request-correction gives a 14-day grace from now and notifies the user with the reason', async () => {
    const { appUser, token } = await submittedUser({ createdAt: daysAgo(100) });
    const before = Date.now();
    const res = await post(`/users/${appUser._id}/request-correction`, reviewer(), {
      reason: 'Your surname does not match the ID.',
    });
    expect(res.status).toBe(200);

    const me = await request(app).get('/api/kyc/me').set(auth(token));
    expect(me.body.status).toBe('REQUIRES_CORRECTION');
    expect(me.body.correctionNotes).toBe('Your surname does not match the ID');
    const deadline = new Date(me.body.deadline).getTime();
    expect(deadline).toBeGreaterThanOrEqual(before + 14 * DAY);
    expect(deadline).toBeLessThanOrEqual(Date.now() + 14 * DAY);
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(200);

    const note = await Notification.findOne({ appUserId: appUser._id, kind: 'CORRECTION_REQUESTED' });
    expect(note.body).toContain('Your surname does not match the ID. Please update');
    expect(
      await KycEvent.countDocuments({
        appUserId: appUser._id,
        type: 'CORRECTION_REQUESTED',
        actor: 'rudo.reviewer',
      })
    ).toBe(1);
  });

  test('expire requires APPROVED and starts a new cycle', async () => {
    const { appUser } = await submittedUser();
    expect(
      (await post(`/users/${appUser._id}/expire`, reviewer(), { reason: 'ID has expired' })).status
    ).toBe(409);
    expect((await post(`/users/${appUser._id}/approve`, reviewer())).status).toBe(200);
    const res = await post(`/users/${appUser._id}/expire`, reviewer(), { reason: 'ID has expired' });
    expect(res.status).toBe(200);
    const updated = await AppUser.findById(appUser._id);
    expect(updated.kyc.status).toBe('EXPIRED');
    expect(updated.kyc.cycle).toBe(1);
    expect(await Notification.countDocuments({ appUserId: appUser._id, kind: 'EXPIRED' })).toBe(1);
    expect(await KycDraft.countDocuments({ appUserId: appUser._id })).toBe(1);
  });

  test('approving clears an existing exemption and leftover draft', async () => {
    const { appUser } = await submittedUser();
    await AppUser.updateOne(
      { _id: appUser._id },
      { $set: { 'kyc.exemption': { until: new Date(Date.now() + 5 * DAY), reason: 'Travel' } } }
    );
    const storageKey = 'a'.repeat(64);
    const storageDir = process.env.KYC_STORAGE_DIR;
    fs.writeFileSync(path.join(storageDir, storageKey), 'x');
    await KycDraft.create({ appUserId: appUser._id, data: { personal: { firstName: 'X' } } });
    await KycDocument.create({
      appUserId: appUser._id,
      kind: 'id_front',
      storageKey,
      mime: 'image/png',
      size: 1,
      sha256: 'b'.repeat(64),
      submissionId: null,
    });

    expect((await post(`/users/${appUser._id}/approve`, reviewer())).status).toBe(200);
    const updated = await AppUser.findById(appUser._id);
    expect(updated.kyc.exemption?.until).toBeUndefined();
    expect(await KycDraft.countDocuments({ appUserId: appUser._id })).toBe(0);
    expect(await KycDocument.countDocuments({ appUserId: appUser._id, submissionId: null })).toBe(0);
    expect(fs.existsSync(path.join(storageDir, storageKey))).toBe(false);
    // Submitted documents stay.
    expect(await KycDocument.countDocuments({ appUserId: appUser._id })).toBe(2);
  });
});

describe('exemptions', () => {
  test('exemption lifts restriction until it expires and is audited', async () => {
    const { appUser, token } = await pastDeadlineUser();
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(403);
    const until = new Date(Date.now() + 10 * DAY).toISOString();
    const res = await post(`/users/${appUser._id}/exemption`, reviewer(), {
      until,
      reason: 'Waiting for a replacement ID',
    });
    expect(res.status).toBe(200);
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(200);

    const event = await KycEvent.findOne({ appUserId: appUser._id, type: 'EXEMPTION_GRANTED' });
    expect(event.actor).toBe('rudo.reviewer');
    expect(event.data.reason).toBe('Waiting for a replacement ID');
    expect(new Date(event.data.until).toISOString()).toBe(until);

    await AppUser.updateOne(
      { _id: appUser._id },
      { $set: { 'kyc.exemption.until': new Date(Date.now() - 1000) } }
    );
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(403);
  });

  test('exemption over 90 days is 400', async () => {
    const { appUser } = await pastDeadlineUser();
    const far = await post(`/users/${appUser._id}/exemption`, reviewer(), {
      until: new Date(Date.now() + 91 * DAY).toISOString(),
      reason: 'Long trip abroad',
    });
    expect(far.status).toBe(400);
    const past = await post(`/users/${appUser._id}/exemption`, reviewer(), {
      until: new Date(Date.now() - DAY).toISOString(),
      reason: 'Long trip abroad',
    });
    expect(past.status).toBe(400);
    const junk = await post(`/users/${appUser._id}/exemption`, reviewer(), {
      until: 'soon',
      reason: 'Long trip abroad',
    });
    expect(junk.status).toBe(400);
  });
});

describe('detail, documents and audit', () => {
  test('document view is audited and the response is the original bytes', async () => {
    const { appUser } = await submittedUser();
    const doc = await KycDocument.findOne({ appUserId: appUser._id, kind: 'id_front' });
    const res = await get(`/documents/${doc._id}`, reviewer()).buffer(true).parse((r, cb) => {
      const chunks = [];
      r.on('data', (c) => chunks.push(c));
      r.on('end', () => cb(null, Buffer.concat(chunks)));
    });
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe('image/png');
    expect(res.headers['cache-control']).toBe('no-store');
    expect(res.headers['content-disposition']).toBe('inline');
    expect(res.headers['content-security-policy']).toBe('sandbox');
    expect(Buffer.compare(res.body, TINY_PNG)).toBe(0);

    const event = await KycEvent.findOne({ appUserId: appUser._id, type: 'DOCUMENT_VIEWED' });
    expect(event.actor).toBe('rudo.reviewer');
    expect(event.data).toEqual({ documentId: doc._id, kind: 'id_front' });

    fs.rmSync(path.join(process.env.KYC_STORAGE_DIR, doc.storageKey));
    const gone = await get(`/documents/${doc._id}`, reviewer());
    expect(gone.status).toBe(404);
    expect(gone.body).toEqual({ message: 'Document not found.' });
    expect((await get('/documents/nope', reviewer())).status).toBe(404);
  });

  test('user document route also sends CSP sandbox', async () => {
    const { token } = await newUser();
    const up = await uploadDoc(token, 'id_front');
    const res = await request(app).get(`/api/kyc/documents/${up.body.id}`).set(auth(token));
    expect(res.status).toBe(200);
    expect(res.headers['content-security-policy']).toBe('sandbox');
  });

  test('ID number masked unless reveal=1, which is audited', async () => {
    const { appUser } = await submittedUser();
    const masked = await get(`/users/${appUser._id}`, reviewer());
    expect(masked.status).toBe(200);
    expect(JSON.stringify(masked.body)).not.toContain(ID_NUMBER.toUpperCase());
    expect(masked.body.user).toMatchObject({
      id: String(appUser._id),
      username: appUser.sipUsername,
      status: 'PENDING_REVIEW',
    });
    const [sub] = masked.body.submissions;
    expect(sub.version).toBe(1);
    expect(sub.identification.idNumberMasked).toBe('•••• X-42');
    expect(sub.identification.idNumber).toBeUndefined();
    expect(sub.documents.map((d) => d.kind).sort()).toEqual(['id_back', 'id_front']);
    expect(masked.body.events.map((e) => e.type)).toContain('SUBMITTED');
    expect(await KycEvent.countDocuments({ type: 'ID_REVEALED' })).toBe(0);

    const revealed = await get(`/users/${appUser._id}?reveal=1`, reviewer());
    expect(revealed.body.submissions[0].identification.idNumber).toBe(ID_NUMBER.toUpperCase());
    const event = await KycEvent.findOne({ appUserId: appUser._id, type: 'ID_REVEALED' });
    expect(event.actor).toBe('rudo.reviewer');
    expect(JSON.stringify(event.data)).not.toContain(ID_NUMBER.toUpperCase());

    expect((await get(`/users/${new mongoose.Types.ObjectId()}`, reviewer())).status).toBe(404);
  });

  test('audit lists events newest first and filters by user and type', async () => {
    const { appUser } = await submittedUser();
    await post(`/users/${appUser._id}/approve`, reviewer());
    const res = await get(`/audit?appUserId=${appUser._id}`, reviewer());
    expect(res.status).toBe(200);
    expect(res.body.items[0].type).toBe('APPROVED');
    expect(res.body.items[0].actor).toBe('rudo.reviewer');
    const typed = await get('/audit?type=SUBMITTED', reviewer());
    expect(typed.body.items.map((e) => e.type)).toEqual(['SUBMITTED']);
  });
});

describe('settings', () => {
  test('PUT settings by kyc_reviewer is 403; invalid values 400; valid change audited and applied to the next request', async () => {
    const { token } = await newUser({ createdAt: daysAgo(40) });
    expect((await get('/settings', reviewer())).body.enforcementDays).toBe(60);

    const denied = await request(app).put(`${BASE}/settings`).set(reviewer()).send({ enforcementDays: 30 });
    expect(denied.status).toBe(403);

    const put = (body) => request(app).put(`${BASE}/settings`).set(superAdmin()).send(body);
    expect((await put({ enforcementDays: 0 })).status).toBe(400);
    expect((await put({ enforcementDays: 366 })).status).toBe(400);
    expect((await put({ enforcementDays: 30.5 })).status).toBe(400);
    expect((await put({ enforcementDays: '30' })).status).toBe(400);
    expect((await put({ secondNudgeDays: 1 })).status).toBe(400);
    expect((await put({ warningBeforeDays: 60 })).status).toBe(400);
    expect((await put({ resubmitGraceDays: 4 })).status).toBe(400);
    expect((await put({ remindersEnabled: 'yes' })).status).toBe(400);
    expect((await put({ rolloutAt: new Date().toISOString() })).status).toBe(400);
    expect(await KycEvent.countDocuments({ type: 'SETTINGS_CHANGED' })).toBe(0);

    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(200);
    const ok = await put({ enforcementDays: 30, remindersEnabled: true });
    expect(ok.status).toBe(200);
    expect(ok.body.enforcementDays).toBe(30);
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(403);

    const event = await KycEvent.findOne({ type: 'SETTINGS_CHANGED' });
    expect(event.actor).toBe('chipo.admin');
    expect(event.data).toEqual({ before: { enforcementDays: 60 }, after: { enforcementDays: 30 } });
  });
});

describe('launch', () => {
  // These tests start from a not-yet-launched settings document and put the shared
  // ROLLOUT back afterwards, so the other tests keep their launched clock.
  const unlaunch = () => KycSettings.updateOne({}, { $set: { rolloutAt: null } });
  afterEach(() => KycSettings.updateOne({}, { $set: { rolloutAt: ROLLOUT } }));
  const launch = (headers) => post('/settings/launch', headers);

  test('only super_admin can launch; it sets rolloutAt once, is audited, and a second launch is 409', async () => {
    await unlaunch();
    expect((await get('/settings', reviewer())).body.rolloutAt).toBeNull();

    const denied = await launch(reviewer());
    expect(denied.status).toBe(403);
    expect((await KycSettings.findOne()).rolloutAt).toBeNull();

    const before = Date.now();
    const res = await launch(superAdmin());
    expect(res.status).toBe(200);
    const rolloutAt = new Date(res.body.rolloutAt).getTime();
    expect(rolloutAt).toBeGreaterThanOrEqual(before);
    expect(rolloutAt).toBeLessThanOrEqual(Date.now());
    expect(res.body.enforcementDays).toBe(60);
    expect((await KycSettings.findOne()).rolloutAt.getTime()).toBe(rolloutAt);

    const events = await KycEvent.find({ type: 'SETTINGS_CHANGED' });
    expect(events).toHaveLength(1);
    expect(events[0].actor).toBe('chipo.admin');
    expect(events[0].data.before).toEqual({ rolloutAt: null });
    expect(new Date(events[0].data.after.rolloutAt).getTime()).toBe(rolloutAt);

    const again = await launch(superAdmin());
    expect(again.status).toBe(409);
    expect(again.body).toEqual({ message: 'KYC has already been launched.' });
    expect((await KycSettings.findOne()).rolloutAt.getTime()).toBe(rolloutAt);
    expect(await KycEvent.countDocuments({ type: 'SETTINGS_CHANGED' })).toBe(1);
  });

  test('launch without the encryption key is 503 and leaves KYC unlaunched', async () => {
    await unlaunch();
    const saved = process.env.KYC_ENCRYPTION_KEY;
    delete process.env.KYC_ENCRYPTION_KEY;
    try {
      const res = await launch(superAdmin());
      expect(res.status).toBe(503);
      expect(res.body).toEqual({ message: 'KYC is temporarily unavailable.' });
    } finally {
      process.env.KYC_ENCRYPTION_KEY = saved;
    }
    expect((await KycSettings.findOne()).rolloutAt).toBeNull();
    expect(await KycEvent.countDocuments({ type: 'SETTINGS_CHANGED' })).toBe(0);
  });

  test('before launch a user past 60 days is not restricted and cannot be reminded', async () => {
    await unlaunch();
    const { appUser, token } = await pastDeadlineUser();
    expect((await request(app).get('/api/cart').set(auth(token))).status).toBe(200);
    const detail = await get(`/users/${appUser._id}`, reviewer());
    expect(detail.body.user).toMatchObject({ status: 'NOT_STARTED', deadline: null });
    expect((await get('/stats', reviewer())).body.restricted).toBe(0);
    expect((await post(`/users/${appUser._id}/remind`, reviewer())).status).toBe(409);
  });
});

describe('manual reminders', () => {
  test('manual remind once per hour', async () => {
    const { appUser } = await newUser({ createdAt: daysAgo(20) });
    const first = await post(`/users/${appUser._id}/remind`, reviewer());
    expect(first.status).toBe(200);
    expect(await Notification.countDocuments({ appUserId: appUser._id, kind: 'REMINDER' })).toBe(1);
    const event = await KycEvent.findOne({ appUserId: appUser._id, type: 'MANUAL_REMINDER' });
    expect(event.actor).toBe('rudo.reviewer');

    const second = await post(`/users/${appUser._id}/remind`, reviewer());
    expect(second.status).toBe(409);
    expect(second.body).toEqual({ message: 'A reminder was sent in the last hour.' });

    await KycEvent.collection.updateOne(
      { _id: event._id },
      { $set: { createdAt: new Date(Date.now() - HOUR - 1000) } }
    );
    expect((await post(`/users/${appUser._id}/remind`, reviewer())).status).toBe(200);
    expect(await Notification.countDocuments({ appUserId: appUser._id, kind: 'REMINDER' })).toBe(2);

    const { appUser: pending } = await newUser({ kyc: { status: 'PENDING_REVIEW' } });
    expect((await post(`/users/${pending._id}/remind`, reviewer())).status).toBe(409);
  });
});
