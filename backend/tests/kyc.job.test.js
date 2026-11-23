const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createAppUserWithToken } = require('./helpers/app_user');

const DAY = 86400000;
const ROLLOUT = new Date('2026-01-01T00:00:00Z');
// Deadline (created + 60 days) is 22 January 2027.
const CREATED = new Date('2026-11-23T00:00:00Z');
const at = (day) => new Date(CREATED.getTime() + day * DAY);

let mongoServer;
let AppUser;
let KycSettings;
let KycEvent;
let Notification;
let JobLock;
let job;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());
  AppUser = require('../models/app_user.model');
  KycSettings = require('../kyc/models/kyc_settings.model');
  KycEvent = require('../kyc/models/kyc_event.model');
  Notification = require('../kyc/models/notification.model');
  JobLock = require('../kyc/models/job_lock.model');
  job = require('../kyc/job');
  await Promise.all([AppUser.init(), KycEvent.init(), Notification.init(), JobLock.init()]);
  await KycSettings.create({ rolloutAt: ROLLOUT });
});

afterEach(async () => {
  jest.restoreAllMocks();
  await KycSettings.updateOne({}, { $set: { remindersEnabled: true } });
  await Promise.all([
    AppUser.deleteMany({}),
    KycEvent.deleteMany({}),
    Notification.deleteMany({}),
    JobLock.deleteMany({}),
  ]);
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

let phoneSeq = 0;
const newUser = async (opts = {}) => {
  phoneSeq += 1;
  const { appUser } = await createAppUserWithToken({
    sipUsername: `+26377400${String(phoneSeq).padStart(4, '0')}`,
    createdAt: CREATED,
    ...opts,
  });
  return appUser;
};

const kindsFor = async (appUserId) =>
  (await Notification.find({ appUserId }).sort({ _id: 1 })).map((n) => n.kind);

describe('runKycJob reminders', () => {
  test('user receives NUDGE_1 on day 1, NUDGE_2 on day 7, reminders on 14, 28, 42, WARNING on 56', async () => {
    const user = await newUser();
    const expected = [
      [1, 'NUDGE_1'],
      [7, 'NUDGE_2'],
      [14, 'REMINDER'],
      [28, 'REMINDER'],
      [42, 'REMINDER'],
      [56, 'WARNING'],
    ];
    for (const [day, kind] of expected) {
      const before = await Notification.countDocuments({ appUserId: user._id });
      const result = await job.runKycJob({ now: at(day) });
      expect(result).toEqual({ reminded: 1, skipped: 0, restricted: 0, failed: 0 });
      const notes = await Notification.find({ appUserId: user._id }).sort({ _id: 1 });
      expect(notes).toHaveLength(before + 1);
      expect(notes[notes.length - 1].kind).toBe(kind);
    }

    const stored = await AppUser.findById(user._id);
    expect(stored.kyc.lastReminderStage).toBe('WARNING');
    expect(stored.kyc.lastReminderAt.toISOString()).toBe(at(56).toISOString());

    const sent = await KycEvent.find({ appUserId: user._id, type: 'REMINDER_SENT' }).sort({ _id: 1 });
    expect(sent.map((e) => e.idempotencyKey)).toEqual(
      ['NUDGE_1', 'NUDGE_2', 'REMINDER_1', 'REMINDER_2', 'REMINDER_3', 'WARNING'].map(
        (s) => `${user._id}:0:${s}`
      )
    );
  });

  test('notification copy matches the templates with the deadline in UTC', async () => {
    const user = await newUser();
    await job.runKycJob({ now: at(1) });
    await job.runKycJob({ now: at(7) });
    await job.runKycJob({ now: at(14) });
    await job.runKycJob({ now: at(56) });
    await job.runKycJob({ now: at(60) });
    const notes = await Notification.find({ appUserId: user._id }).sort({ _id: 1 });
    expect(notes.map((n) => [n.kind, n.title, n.body])).toEqual([
      [
        'NUDGE_1',
        'Verify your number',
        'POTRAZ rules require us to confirm who owns each number. It takes about 5 minutes. Complete it before 22 January 2027.',
      ],
      [
        'NUDGE_2',
        'Your KYC is still open',
        'Finish your KYC before 22 January 2027 to keep calling, shopping and paying without interruption.',
      ],
      [
        'REMINDER',
        'Reminder: complete your KYC',
        'Your KYC verification is still outstanding. Complete it before 22 January 2027.',
      ],
      [
        'WARNING',
        'Your account will be limited soon',
        'Complete your KYC before 22 January 2027. After that, calls, shopping, payments and posts will be paused until you verify.',
      ],
      [
        'RESTRICTED',
        'Your account is limited',
        'We have paused calls, shopping, payments and posts because your KYC is not complete. Emergency calls still work. Complete KYC to restore access.',
      ],
    ]);
    for (const n of notes) {
      expect(n.deliveredVia).toEqual(['in_app']);
      expect(n.readAt).toBeNull();
      expect(`${n.title} ${n.body}`).not.toContain('—');
    }
  });

  test('running the job twice on the same day sends nothing new', async () => {
    const user = await newUser();
    await job.runKycJob({ now: at(1) });
    const second = await job.runKycJob({ now: at(1) });
    expect(second).toEqual({ reminded: 0, skipped: 0, restricted: 0, failed: 0 });
    expect(await kindsFor(user._id)).toEqual(['NUDGE_1']);
  });

  test('a REMINDER_SENT event already recorded for the stage blocks a second send', async () => {
    const user = await newUser();
    await KycEvent.create({
      appUserId: user._id,
      actor: 'system',
      type: 'REMINDER_SENT',
      idempotencyKey: `${user._id}:0:NUDGE_1`,
    });
    const result = await job.runKycJob({ now: at(1) });
    expect(result.reminded).toBe(0);
    expect(await kindsFor(user._id)).toEqual([]);
  });

  test('job on day 5 sends nothing', async () => {
    const user = await newUser();
    await job.runKycJob({ now: at(1) });
    const result = await job.runKycJob({ now: at(5) });
    expect(result).toEqual({ reminded: 0, skipped: 0, restricted: 0, failed: 0 });
    expect(await kindsFor(user._id)).toEqual(['NUDGE_1']);
  });

  test('job restarted on day 45 after a gap sends only REMINDER_3 and records skips', async () => {
    const user = await newUser();
    await job.runKycJob({ now: at(1) });
    const result = await job.runKycJob({ now: at(45) });
    expect(result).toEqual({ reminded: 1, skipped: 3, restricted: 0, failed: 0 });
    expect(await kindsFor(user._id)).toEqual(['NUDGE_1', 'REMINDER']);

    const skips = await KycEvent.find({ appUserId: user._id, type: 'REMINDER_SKIPPED' }).sort({ _id: 1 });
    expect(skips.map((e) => e.idempotencyKey)).toEqual(
      ['NUDGE_2', 'REMINDER_1', 'REMINDER_2'].map((s) => `${user._id}:0:${s}`)
    );
    const sent = await KycEvent.find({ appUserId: user._id, type: 'REMINDER_SENT' });
    expect(sent.map((e) => e.idempotencyKey).sort()).toEqual(
      [`${user._id}:0:NUDGE_1`, `${user._id}:0:REMINDER_3`].sort()
    );
    const stored = await AppUser.findById(user._id);
    expect(stored.kyc.lastReminderStage).toBe('REMINDER_3');
  });

  test('a user stored without a kyc subdocument is treated as NOT_STARTED', async () => {
    const { insertedId } = await AppUser.collection.insertOne({
      sipUsername: '+263774999999',
      createdAt: CREATED,
      updatedAt: CREATED,
    });
    const result = await job.runKycJob({ now: at(1) });
    expect(result.reminded).toBe(1);
    expect(await kindsFor(insertedId)).toEqual(['NUDGE_1']);
    const stored = await AppUser.collection.findOne({ _id: insertedId });
    expect(stored.kyc.lastReminderStage).toBe('NUDGE_1');
  });

  test('before launch the job sends nothing and restricts nobody', async () => {
    await KycSettings.updateOne({}, { $set: { rolloutAt: null } });
    try {
      const user = await newUser();
      for (const day of [1, 7, 14, 56, 61]) {
        expect(await job.runKycJob({ now: at(day) })).toEqual({
          reminded: 0,
          skipped: 0,
          restricted: 0,
          failed: 0,
        });
      }
      expect(await kindsFor(user._id)).toEqual([]);
      expect(await KycEvent.countDocuments({})).toBe(0);
      const stored = await AppUser.findById(user._id);
      expect(stored.kyc.lastReminderStage).toBeNull();
      expect(stored.kyc.restrictedAt).toBeUndefined();
    } finally {
      await KycSettings.updateOne({}, { $set: { rolloutAt: ROLLOUT } });
    }
  });

  test('approved and pending users get no reminders', async () => {
    const approved = await newUser({ kyc: { status: 'APPROVED' } });
    const pending = await newUser({ kyc: { status: 'PENDING_REVIEW' } });
    for (const day of [1, 7, 56, 61]) await job.runKycJob({ now: at(day) });
    expect(await Notification.countDocuments({})).toBe(0);
    expect(await KycEvent.countDocuments({})).toBe(0);
    for (const u of [approved, pending]) {
      const stored = await AppUser.findById(u._id);
      expect(stored.kyc.restrictedAt).toBeUndefined();
    }
  });

  test('user who submits stops receiving reminders', async () => {
    const user = await newUser({ kyc: { status: 'IN_PROGRESS' } });
    await job.runKycJob({ now: at(1) });
    await AppUser.updateOne({ _id: user._id }, { $set: { 'kyc.status': 'PENDING_REVIEW' } });
    for (const day of [7, 14, 56, 60]) await job.runKycJob({ now: at(day) });
    expect(await kindsFor(user._id)).toEqual(['NUDGE_1']);
  });

  test('restriction is cached with a RESTRICTED notification on day 60, once', async () => {
    const user = await newUser();
    await job.runKycJob({ now: at(56) });
    const first = await job.runKycJob({ now: at(60) });
    expect(first).toEqual({ reminded: 1, skipped: 0, restricted: 1, failed: 0 });
    const second = await job.runKycJob({ now: at(60) });
    expect(second).toEqual({ reminded: 0, skipped: 0, restricted: 0, failed: 0 });
    await job.runKycJob({ now: at(61) });

    expect(await kindsFor(user._id)).toEqual(['WARNING', 'RESTRICTED']);
    const stored = await AppUser.findById(user._id);
    expect(stored.kyc.restrictedAt.toISOString()).toBe(at(60).toISOString());
    expect(stored.kyc.lastReminderStage).toBe('RESTRICTED');
    const restrictedEvents = await KycEvent.find({ appUserId: user._id, type: 'RESTRICTED' });
    expect(restrictedEvents.map((e) => e.idempotencyKey)).toEqual([`${user._id}:restricted:0`]);
    expect(
      await KycEvent.countDocuments({ idempotencyKey: `${user._id}:0:RESTRICTED`, type: 'REMINDER_SENT' })
    ).toBe(1);
  });

  test('a user already cached as restricted is not counted again', async () => {
    const user = await newUser({ kyc: { restrictedAt: at(60), lastReminderStage: 'RESTRICTED' } });
    const result = await job.runKycJob({ now: at(62) });
    expect(result).toEqual({ reminded: 0, skipped: 0, restricted: 0, failed: 0 });
    expect(await kindsFor(user._id)).toEqual([]);
  });

  test('REQUIRES_CORRECTION cycle sends WARNING and RESTRICTED against the new deadline', async () => {
    // Cycle 1 started 2027-03-01; resubmit grace 14 days, so the deadline is 15 March 2027.
    const cycleStart = new Date('2027-03-01T00:00:00Z');
    const user = await newUser({
      createdAt: new Date('2026-06-01T00:00:00Z'),
      kyc: { status: 'REQUIRES_CORRECTION', cycle: 1, cycleStartedAt: cycleStart },
    });
    // A cycle-0 WARNING must not block the cycle-1 one.
    await KycEvent.create({
      appUserId: user._id,
      actor: 'system',
      type: 'REMINDER_SENT',
      idempotencyKey: `${user._id}:0:WARNING`,
    });

    const day = (n) => new Date(cycleStart.getTime() + n * DAY);
    expect(await job.runKycJob({ now: day(9) })).toEqual({
      reminded: 0,
      skipped: 0,
      restricted: 0,
      failed: 0,
    });
    await job.runKycJob({ now: day(10) });
    await job.runKycJob({ now: day(14) });

    const notes = await Notification.find({ appUserId: user._id }).sort({ _id: 1 });
    expect(notes.map((n) => n.kind)).toEqual(['WARNING', 'RESTRICTED']);
    expect(notes[0].body).toBe(
      'Complete your KYC before 15 March 2027. After that, calls, shopping, payments and posts will be paused until you verify.'
    );
    const keys = (await KycEvent.find({ appUserId: user._id, type: 'REMINDER_SENT' })).map(
      (e) => e.idempotencyKey
    );
    expect(keys).toEqual(
      expect.arrayContaining([`${user._id}:1:WARNING`, `${user._id}:1:RESTRICTED`])
    );
    const stored = await AppUser.findById(user._id);
    expect(stored.kyc.restrictedAt.toISOString()).toBe(day(14).toISOString());
    expect(await KycEvent.countDocuments({ idempotencyKey: `${user._id}:restricted:1` })).toBe(1);
  });

  test('remindersEnabled false sends nothing but still caches restriction', async () => {
    await KycSettings.updateOne({}, { $set: { remindersEnabled: false } });
    const user = await newUser();
    for (const day of [1, 7, 56]) {
      expect(await job.runKycJob({ now: at(day) })).toEqual({
        reminded: 0,
        skipped: 0,
        restricted: 0,
        failed: 0,
      });
    }
    const result = await job.runKycJob({ now: at(60) });
    expect(result).toEqual({ reminded: 0, skipped: 0, restricted: 1, failed: 0 });
    expect(await Notification.countDocuments({})).toBe(0);
    const stored = await AppUser.findById(user._id);
    expect(stored.kyc.restrictedAt.toISOString()).toBe(at(60).toISOString());
    expect(await KycEvent.countDocuments({ appUserId: user._id, type: 'RESTRICTED' })).toBe(1);
    expect(await KycEvent.countDocuments({ type: { $in: ['REMINDER_SENT', 'REMINDER_SKIPPED'] } })).toBe(0);
  });

  test('two concurrent runKycJob calls on the same day still send one notification', async () => {
    const users = await Promise.all([newUser(), newUser(), newUser()]);
    const results = await Promise.all([
      job.runKycJob({ now: at(1) }),
      job.runKycJob({ now: at(1) }),
    ]);
    expect(results[0].reminded + results[1].reminded).toBe(3);
    for (const u of users) expect(await kindsFor(u._id)).toEqual(['NUDGE_1']);
  });

  test('processes users across several batches', async () => {
    const users = [];
    for (let i = 0; i < 5; i += 1) users.push(await newUser());
    const result = await job.runKycJob({ now: at(1), batchSize: 2 });
    expect(result.reminded).toBe(5);
    for (const u of users) expect(await kindsFor(u._id)).toEqual(['NUDGE_1']);
  });

  test('a failed notification removes the event so the next run retries', async () => {
    const user = await newUser();
    jest.spyOn(Notification.prototype, 'save').mockRejectedValueOnce(new Error('db down'));
    jest.spyOn(console, 'error').mockImplementation(() => {});
    const failedRun = await job.runKycJob({ now: at(1) });
    expect(failedRun).toEqual({ reminded: 0, skipped: 0, restricted: 0, failed: 1 });
    expect(await KycEvent.countDocuments({ appUserId: user._id, type: 'REMINDER_SENT' })).toBe(0);
    expect((await AppUser.findById(user._id)).kyc.lastReminderStage).toBeNull();

    const retry = await job.runKycJob({ now: at(1) });
    expect(retry).toEqual({ reminded: 1, skipped: 0, restricted: 0, failed: 0 });
    expect(await kindsFor(user._id)).toEqual(['NUDGE_1']);
  });

  test('one failing user does not stop the run for others', async () => {
    const bad = await newUser();
    const good = await newUser();
    const realCreate = KycEvent.create.bind(KycEvent);
    jest.spyOn(KycEvent, 'create').mockImplementation((doc) => {
      if (String(doc.appUserId) === String(bad._id)) return Promise.reject(new Error('boom'));
      return realCreate(doc);
    });
    jest.spyOn(console, 'error').mockImplementation(() => {});
    const result = await job.runKycJob({ now: at(1) });
    expect(result).toEqual({ reminded: 1, skipped: 0, restricted: 0, failed: 1 });
    expect(await kindsFor(good._id)).toEqual(['NUDGE_1']);
    expect(await kindsFor(bad._id)).toEqual([]);
  });
});

describe('job lease', () => {
  test('lease: second acquire fails while the first is held, succeeds after expiry', async () => {
    const t0 = new Date('2026-12-01T00:00:00Z');
    const ttl = 60000;
    expect(await job.acquireLease('a', t0, ttl)).toBe(true);
    expect(await job.acquireLease('b', new Date(t0.getTime() + 1000), ttl)).toBe(false);
    // The holder can renew.
    expect(await job.acquireLease('a', new Date(t0.getTime() + 2000), ttl)).toBe(true);
    // After expiry another holder takes over.
    expect(await job.acquireLease('b', new Date(t0.getTime() + 2000 + ttl + 1), ttl)).toBe(true);
    expect(await job.acquireLease('a', new Date(t0.getTime() + 2000 + ttl + 2), ttl)).toBe(false);
    expect(await JobLock.countDocuments({ name: 'kyc' })).toBe(1);
  });

  test('concurrent first acquires give the lease to exactly one holder', async () => {
    const now = new Date();
    const results = await Promise.all(['a', 'b', 'c'].map((h) => job.acquireLease(h, now, 60000)));
    expect(results.filter(Boolean)).toHaveLength(1);
  });

  test('releaseLease frees the lease only for its holder', async () => {
    const now = new Date();
    await job.acquireLease('a', now, 60000);
    await job.releaseLease('b');
    expect(await job.acquireLease('b', now, 60000)).toBe(false);
    await job.releaseLease('a');
    expect(await job.acquireLease('b', now, 60000)).toBe(true);
  });
});

describe('startKycJob', () => {
  test('runs the job after the initial delay and stops cleanly', async () => {
    const user = await newUser({ createdAt: new Date(Date.now() - 2 * DAY) });
    jest.spyOn(console, 'info').mockImplementation(() => {});
    const stop = job.startKycJob({ intervalMs: 60000, initialDelayMs: 0 });
    try {
      for (let i = 0; i < 100; i += 1) {
        if (await Notification.countDocuments({ appUserId: user._id })) break;
        await new Promise((r) => setTimeout(r, 20));
      }
      expect(await kindsFor(user._id)).toEqual(['NUDGE_1']);
    } finally {
      await stop();
    }
    expect(await JobLock.countDocuments({})).toBe(0);
  });
});
