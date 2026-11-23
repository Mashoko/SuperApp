const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { computeKycState, reminderSchedule } = require('../kyc/schedule');
const KycSettings = require('../kyc/models/kyc_settings.model');

const DAY = 86400000;
const CREATED = new Date('2026-01-01T00:00:00Z');
const ROLLOUT = new Date('2025-12-01T00:00:00Z');
const day = (n) => new Date(CREATED.getTime() + n * DAY);

const settings = (overrides = {}) => ({
  firstNudgeDays: 1,
  secondNudgeDays: 7,
  reminderIntervalDays: 14,
  warningBeforeDays: 4,
  enforcementDays: 60,
  resubmitGraceDays: 14,
  remindersEnabled: true,
  rolloutAt: ROLLOUT,
  ...overrides,
});

const user = (kyc, createdAt = CREATED) => ({ createdAt, kyc });

describe('reminderSchedule', () => {
  test('default schedule reproduces days 1, 7, 14, 28, 42, 56, 60', () => {
    const sched = reminderSchedule(user(undefined), settings());
    expect(sched.map((s) => s.stage)).toEqual([
      'NUDGE_1',
      'NUDGE_2',
      'REMINDER_1',
      'REMINDER_2',
      'REMINDER_3',
      'WARNING',
      'RESTRICTED',
    ]);
    expect(sched.map((s) => (s.at.getTime() - CREATED.getTime()) / DAY)).toEqual([
      1, 7, 14, 28, 42, 56, 60,
    ]);
  });

  test('colliding stages keep the schedule strictly increasing with RESTRICTED last', () => {
    const offsets = (sched) => sched.map((s) => (s.at.getTime() - CREATED.getTime()) / DAY);
    const check = (sched) => {
      for (let i = 1; i < sched.length; i += 1) expect(sched[i].at > sched[i - 1].at).toBe(true);
      expect(new Set(sched.map((s) => s.stage)).size).toBe(sched.length);
      expect(sched[sched.length - 1]).toEqual({ stage: 'RESTRICTED', at: day(60) });
    };

    const interval7 = reminderSchedule(user(undefined), settings({ reminderIntervalDays: 7 }));
    check(interval7);
    expect(interval7.map((s) => s.stage).slice(0, 3)).toEqual(['NUDGE_1', 'NUDGE_2', 'REMINDER_2']);

    const noWarning = reminderSchedule(user(undefined), settings({ warningBeforeDays: 0 }));
    check(noWarning);
    expect(noWarning.map((s) => s.stage)).not.toContain('WARNING');
    expect(offsets(noWarning)).toEqual([1, 7, 14, 28, 42, 56, 60]);

    const negative = reminderSchedule(user(undefined), settings({ warningBeforeDays: -5 }));
    check(negative);
    expect(negative.map((s) => s.stage)).not.toContain('WARNING');

    const nudgeAtDeadline = reminderSchedule(
      user(undefined),
      settings({ enforcementDays: 7, firstNudgeDays: 7, warningBeforeDays: 0 })
    );
    expect(nudgeAtDeadline).toEqual([{ stage: 'RESTRICTED', at: day(7) }]);
  });

  test('correction cycle uses resubmitGraceDays from cycleStartedAt', () => {
    const u = user({ status: 'REQUIRES_CORRECTION', cycle: 1, cycleStartedAt: day(80) });
    const sched = reminderSchedule(u, settings());
    expect(sched).toEqual([
      { stage: 'WARNING', at: day(90) },
      { stage: 'RESTRICTED', at: day(94) },
    ]);
    expect(computeKycState(u, settings(), day(80)).deadline).toEqual(day(94));
    expect(computeKycState(u, settings(), day(93)).restricted).toBe(false);
    expect(computeKycState(u, settings(), day(94)).restricted).toBe(true);
  });
});

describe('computeKycState', () => {
  test('clock starts at rolloutAt for users created before rollout', () => {
    const u = user(undefined, new Date('2025-06-01T00:00:00Z'));
    const s = settings({ rolloutAt: new Date('2026-01-01T00:00:00Z') });
    const state = computeKycState(u, s, new Date('2026-01-10T00:00:00Z'));
    expect(state.deadline).toEqual(new Date('2026-03-02T00:00:00Z'));
  });

  test('not restricted on day 59, restricted on day 60', () => {
    const u = user({ status: 'NOT_STARTED', cycle: 0 });
    const d59 = computeKycState(u, settings(), day(59));
    expect(d59.restricted).toBe(false);
    expect(d59.status).toBe('NOT_STARTED');
    expect(d59.underlyingStatus).toBe('NOT_STARTED');
    const d60 = computeKycState(u, settings(), day(60));
    expect(d60.restricted).toBe(true);
    expect(d60.status).toBe('RESTRICTED');
    expect(d60.underlyingStatus).toBe('NOT_STARTED');
    expect(d60.deadline).toEqual(day(60));
  });

  test('missing kyc subdocument is treated as NOT_STARTED, cycle 0', () => {
    const state = computeKycState(user(undefined), settings(), day(60));
    expect(state.underlyingStatus).toBe('NOT_STARTED');
    expect(state.restricted).toBe(true);
  });

  test('PENDING_REVIEW and APPROVED are never restricted and have no due stage', () => {
    for (const status of ['PENDING_REVIEW', 'APPROVED']) {
      const state = computeKycState(user({ status, cycle: 0 }), settings(), day(200));
      expect(state.restricted).toBe(false);
      expect(state.status).toBe(status);
      expect(state.deadline).toBeNull();
      expect(state.dueStage).toBeNull();
      expect(state.skippedStages).toEqual([]);
    }
  });

  test('IN_PROGRESS, REJECTED, REQUIRES_CORRECTION, EXPIRED are restrictable', () => {
    for (const status of ['IN_PROGRESS', 'REJECTED', 'REQUIRES_CORRECTION', 'EXPIRED']) {
      const state = computeKycState(user({ status, cycle: 0 }), settings(), day(60));
      expect(state.restricted).toBe(true);
      expect(state.status).toBe('RESTRICTED');
      expect(state.underlyingStatus).toBe(status);
    }
  });

  test('active exemption suppresses restriction until it expires', () => {
    const u = user({
      status: 'NOT_STARTED',
      cycle: 0,
      exemption: { until: day(70), reason: 'travel', grantedBy: 'admin1' },
    });
    const d65 = computeKycState(u, settings(), day(65));
    expect(d65.restricted).toBe(false);
    expect(d65.exemptUntil).toEqual(day(70));
    const d71 = computeKycState(u, settings(), day(71));
    expect(d71.restricted).toBe(true);
    expect(d71.exemptUntil).toBeNull();
  });

  test('exempt until day 70: no RESTRICTED due on day 65; RESTRICTED due on day 71', () => {
    const kyc = {
      status: 'NOT_STARTED',
      cycle: 0,
      lastReminderStage: 'WARNING',
      exemption: { until: day(70), reason: 'travel', grantedBy: 'admin1' },
    };
    const d65 = computeKycState(user(kyc), settings(), day(65));
    expect(d65.restricted).toBe(false);
    expect(d65.dueStage).toBeNull();
    expect(d65.skippedStages).toEqual([]);
    const d71 = computeKycState(user(kyc), settings(), day(71));
    expect(d71.restricted).toBe(true);
    expect(d71.dueStage).toBe('RESTRICTED');

    const earlier = user({ ...kyc, lastReminderStage: 'REMINDER_3' });
    const e65 = computeKycState(earlier, settings(), day(65));
    expect(e65.dueStage).toBe('WARNING');
    expect(e65.skippedStages).toEqual([]);
  });

  test('changing enforcementDays moves the deadline', () => {
    const u = user({ status: 'NOT_STARTED', cycle: 0 });
    const s = settings({ enforcementDays: 30 });
    expect(computeKycState(u, s, day(29)).restricted).toBe(false);
    expect(computeKycState(u, s, day(30)).restricted).toBe(true);
  });

  test('remindersEnabled false gives no due stage but restriction still applies', () => {
    const u = user({ status: 'NOT_STARTED', cycle: 0 });
    const state = computeKycState(u, settings({ remindersEnabled: false }), day(61));
    expect(state.dueStage).toBeNull();
    expect(state.skippedStages).toEqual([]);
    expect(state.restricted).toBe(true);
  });

  test('due stage follows the schedule and respects lastReminderStage', () => {
    const fresh = user({ status: 'NOT_STARTED', cycle: 0, lastReminderStage: null });
    expect(computeKycState(fresh, settings(), day(0)).dueStage).toBeNull();
    expect(computeKycState(fresh, settings(), day(1)).dueStage).toBe('NUDGE_1');
    const sent = user({ status: 'NOT_STARTED', cycle: 0, lastReminderStage: 'NUDGE_1' });
    expect(computeKycState(sent, settings(), day(3)).dueStage).toBeNull();
  });

  test('after a long gap only the latest due stage is due, the rest are skipped', () => {
    const u = user({ status: 'NOT_STARTED', cycle: 0, lastReminderStage: 'NUDGE_1' });
    const state = computeKycState(u, settings(), day(45));
    expect(state.dueStage).toBe('REMINDER_3');
    expect(state.skippedStages).toEqual(['NUDGE_2', 'REMINDER_1', 'REMINDER_2']);
  });
});

describe('before launch (rolloutAt null)', () => {
  test('no deadline, schedule, due stage or restriction, but status is still reported', () => {
    const s = settings({ rolloutAt: null });
    for (const status of ['NOT_STARTED', 'IN_PROGRESS', 'REJECTED', 'EXPIRED']) {
      const u = user({ status, cycle: status === 'REJECTED' ? 1 : 0, cycleStartedAt: day(10) });
      expect(reminderSchedule(u, s)).toEqual([]);
      expect(computeKycState(u, s, day(200))).toEqual({
        status,
        underlyingStatus: status,
        restricted: false,
        deadline: null,
        exemptUntil: null,
        dueStage: null,
        skippedStages: [],
      });
    }
  });

  test('a cycle started before launch counts its grace period from rolloutAt', () => {
    const rolloutAt = day(100);
    const s = settings({ rolloutAt });
    const u = user({ status: 'REJECTED', cycle: 1, cycleStartedAt: day(50) });
    const state = computeKycState(u, s, day(101));
    expect(state.restricted).toBe(false);
    expect(state.deadline).toEqual(day(114));
    expect(computeKycState(u, s, day(114)).restricted).toBe(true);
  });
});

describe('AppUser.kyc defaults', () => {
  test('a new AppUser starts NOT_STARTED in cycle 0 and computes cleanly', () => {
    const AppUser = require('../models/app_user.model');
    const u = new AppUser({ sipUsername: '263771234567' });
    expect(u.kyc.status).toBe('NOT_STARTED');
    expect(u.kyc.cycle).toBe(0);
    expect(u.kyc.lastReminderStage).toBeNull();
    expect(u.validateSync()).toBeUndefined();
    u.createdAt = CREATED;
    expect(computeKycState(u, settings(), day(60)).status).toBe('RESTRICTED');
  });
});

describe('KycSettings.getSettings', () => {
  let mongoServer;

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    await mongoose.connect(mongoServer.getUri());
    await KycSettings.init();
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  test('getSettings creates singleton once with defaults', async () => {
    const [a, b] = await Promise.all([KycSettings.getSettings(), KycSettings.getSettings()]);
    const c = await KycSettings.getSettings();
    expect(await KycSettings.countDocuments()).toBe(1);
    expect(String(a._id)).toBe(String(b._id));
    expect(String(a._id)).toBe(String(c._id));
    expect(c.firstNudgeDays).toBe(1);
    expect(c.secondNudgeDays).toBe(7);
    expect(c.reminderIntervalDays).toBe(14);
    expect(c.warningBeforeDays).toBe(4);
    expect(c.enforcementDays).toBe(60);
    expect(c.resubmitGraceDays).toBe(14);
    expect(c.remindersEnabled).toBe(true);
    // Launching is an explicit admin step, so getSettings never starts the clock.
    expect(c.rolloutAt).toBeNull();
    expect(a.rolloutAt).toBeNull();
  });
});
