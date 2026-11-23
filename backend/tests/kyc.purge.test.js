const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createAppUserWithToken } = require('./helpers/app_user');

const TINY_PNG = fs.readFileSync(path.join(__dirname, 'fixtures', 'tiny.png'));
const SIP = '+263771110000';
const OTHER_SIP = '+263771110001';
const APPLY_SIP = '+263771110002';

let mongoServer;
let purgeUser;
let AppUser;
let KycDraft;
let KycDocument;
let KycSubmission;
let KycEvent;
let Notification;
let saveEncrypted;

const storedFile = (key) => path.join(process.env.KYC_STORAGE_DIR, key);

// Creates one of every record kind for an AppUser and returns the stored file keys.
async function seedUser(appUser) {
  const appUserId = appUser._id;
  const keys = [];
  const docs = [];
  for (const kind of ['id_front', 'id_back']) {
    const saved = await saveEncrypted(TINY_PNG);
    keys.push(saved.storageKey);
    docs.push(
      await KycDocument.create({
        appUserId,
        kind,
        storageKey: saved.storageKey,
        mime: 'image/png',
        size: saved.size,
        sha256: saved.sha256,
      })
    );
  }
  await KycDraft.create({ appUserId, data: { personal: { firstName: 'Tendai' } } });
  await KycSubmission.create({
    appUserId,
    version: 1,
    phone: SIP,
    submittedAt: new Date(),
    personal: { firstName: 'Tendai', lastName: 'Moyo' },
    documentIds: docs.map((d) => d._id),
  });
  await Notification.create({ appUserId, kind: 'NUDGE_1', title: 't', body: 'b' });
  await KycEvent.create({
    appUserId,
    actor: 'staff-jane',
    type: 'SUBMITTED',
    data: { version: 1, note: 'personal detail' },
  });
  return keys;
}

const counts = async (appUserId) => ({
  drafts: await KycDraft.countDocuments({ appUserId }),
  documents: await KycDocument.countDocuments({ appUserId }),
  submissions: await KycSubmission.countDocuments({ appUserId }),
  notifications: await Notification.countDocuments({ appUserId }),
  events: await KycEvent.countDocuments({ appUserId }),
});

const ALL_ONE = { drafts: 1, documents: 2, submissions: 1, notifications: 1, events: 1 };

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());
  AppUser = require('../models/app_user.model');
  KycDraft = require('../kyc/models/kyc_draft.model');
  KycDocument = require('../kyc/models/kyc_document.model');
  KycSubmission = require('../kyc/models/kyc_submission.model');
  KycEvent = require('../kyc/models/kyc_event.model');
  Notification = require('../kyc/models/notification.model');
  ({ saveEncrypted } = require('../kyc/storage'));
  ({ purgeUser } = require('../scripts/kyc-purge-user'));
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

describe('kyc-purge-user', () => {
  test('dry run reports counts and changes nothing', async () => {
    const { appUser } = await createAppUserWithToken({ sipUsername: SIP });
    const keys = await seedUser(appUser);

    const result = await purgeUser(SIP, { apply: false });

    expect(result).toEqual({ found: true, applied: false, counts: ALL_ONE });
    expect(await counts(appUser._id)).toEqual(ALL_ONE);
    for (const key of keys) expect(fs.existsSync(storedFile(key))).toBe(true);
    const event = await KycEvent.findOne({ appUserId: appUser._id });
    expect(event.data.note).toBe('personal detail');
  });

  test('apply deletes records and files, scrubs events, leaves other users and AppUser.kyc', async () => {
    const { appUser } = await createAppUserWithToken({
      sipUsername: APPLY_SIP,
      kyc: { status: 'PENDING_REVIEW', cycle: 1 },
    });
    const { appUser: other } = await createAppUserWithToken({ sipUsername: OTHER_SIP });
    const keys = await seedUser(appUser);
    const otherKeys = await seedUser(other);

    const result = await purgeUser('263 77-111 0002', { apply: true });

    expect(result).toEqual({ found: true, applied: true, counts: ALL_ONE });
    expect(await counts(appUser._id)).toEqual({
      drafts: 0,
      documents: 0,
      submissions: 0,
      notifications: 0,
      events: 1,
    });
    for (const key of keys) expect(fs.existsSync(storedFile(key))).toBe(false);

    const event = await KycEvent.findOne({ appUserId: appUser._id }).lean();
    expect(event.data).toEqual({});
    expect(event.type).toBe('SUBMITTED');
    expect(event.actor).toBe('staff-jane');
    expect(event.createdAt).toBeInstanceOf(Date);

    const kept = await AppUser.findById(appUser._id).lean();
    expect(kept.kyc.status).toBe('PENDING_REVIEW');
    expect(kept.kyc.cycle).toBe(1);

    expect(await counts(other._id)).toEqual(ALL_ONE);
    for (const key of otherKeys) expect(fs.existsSync(storedFile(key))).toBe(true);
    expect((await KycEvent.findOne({ appUserId: other._id })).data.note).toBe('personal detail');
  });

  test('unknown user reports not found and deletes nothing', async () => {
    const result = await purgeUser('+263770000999', { apply: true });
    expect(result).toEqual({ found: false, applied: false, counts: null });
  });
});
