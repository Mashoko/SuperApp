const crypto = require('crypto');
const os = require('os');
const AppUser = require('../models/app_user.model');
const KycSettings = require('./models/kyc_settings.model');
const KycEvent = require('./models/kyc_event.model');
const JobLock = require('./models/job_lock.model');
const { computeKycState, isLaunched, RESTRICTABLE_STATUSES } = require('./schedule');
const { notify } = require('./notifications');
const { markRestricted } = require('./require_kyc_access.middleware');

const LOCK_NAME = 'kyc';
const DEFAULT_INTERVAL_MS = 900000;
const DEFAULT_INITIAL_DELAY_MS = 10000;
// null also matches AppUsers created before the kyc subdocument existed (NOT_STARTED).
const SCANNED_STATUSES = [...RESTRICTABLE_STATUSES, null];

const isDuplicateKey = (err) => err?.code === 11000;

// Logs only the error's name and code: messages can carry user data.
const logError = (what, err) => console.error(`KYC job ${what}:`, err?.name, err?.code);

const reminderKey = (appUserId, cycle, stage) => `${appUserId}:${cycle}:${stage}`;
const templateFor = (stage) => (stage.startsWith('REMINDER_') ? 'REMINDER' : stage);

// Inserts an event under its idempotency key. Resolves false when the key already exists.
const insertOnce = async (event) => {
  try {
    await KycEvent.create(event);
    return true;
  } catch (err) {
    if (isDuplicateKey(err)) return false;
    throw err;
  }
};

const cycleFilter = (cycle) => (cycle === 0 ? { $in: [0, null] } : cycle);

// Moves lastReminderStage forward only if nobody changed it (or the cycle) since we read it.
// Also matches when it already equals stage: a concurrent run that hit this stage's
// duplicate key may have advanced it first, and the sender still records lastReminderAt.
const advanceStage = (appUser, cycle, stage, now, sent) => {
  const $set = { 'kyc.lastReminderStage': stage };
  if (sent) $set['kyc.lastReminderAt'] = now;
  return AppUser.updateOne(
    {
      _id: appUser._id,
      'kyc.cycle': cycleFilter(cycle),
      'kyc.lastReminderStage': { $in: [appUser.kyc?.lastReminderStage || null, stage] },
    },
    { $set }
  );
};

// Undoes a duplicate-path advance to stage after the sender's notification failed, so the
// next run retries the stage.
const revertStage = (appUser, cycle, stage) =>
  AppUser.updateOne(
    { _id: appUser._id, 'kyc.cycle': cycleFilter(cycle), 'kyc.lastReminderStage': stage },
    { $set: { 'kyc.lastReminderStage': appUser.kyc?.lastReminderStage || null } }
  );

// Sends the due reminder and records skipped stages for one user. Returns
// { reminded, skipped, failed } counts for this user.
const remindUser = async (appUser, state, now) => {
  const result = { reminded: 0, skipped: 0, failed: 0 };
  const cycle = Number(appUser.kyc?.cycle) || 0;
  const base = { appUserId: appUser._id, actor: 'system' };

  for (const stage of state.skippedStages) {
    const inserted = await insertOnce({
      ...base,
      type: 'REMINDER_SKIPPED',
      data: { cycle, stage },
      idempotencyKey: reminderKey(appUser._id, cycle, stage),
    });
    if (inserted) result.skipped += 1;
  }

  const stage = state.dueStage;
  if (!stage) {
    const lastSkipped = state.skippedStages[state.skippedStages.length - 1];
    if (lastSkipped) await advanceStage(appUser, cycle, lastSkipped, now, false);
    return result;
  }

  const key = reminderKey(appUser._id, cycle, stage);
  // The event goes first: its unique key is what stops a second send of this stage.
  const claimed = await insertOnce({
    ...base,
    type: 'REMINDER_SENT',
    data: { cycle, stage },
    idempotencyKey: key,
  });
  if (!claimed) {
    // The stage is already recorded (sent, skipped, or being sent by a concurrent run).
    // Still move lastReminderStage on, or every run would retry this insert forever.
    await advanceStage(appUser, cycle, stage, now, false);
    return result;
  }

  try {
    await notify(appUser._id, templateFor(stage), { deadline: state.deadline });
  } catch (err) {
    logError('notification failed', err);
    // Release the claim so the next run retries this stage.
    await KycEvent.deleteOne({ idempotencyKey: key }).catch((e) => logError('cleanup failed', e));
    await revertStage(appUser, cycle, stage).catch((e) => logError('cleanup failed', e));
    result.failed = 1;
    return result;
  }

  await advanceStage(appUser, cycle, stage, now, true);
  result.reminded = 1;
  return result;
};

// One pass over every user who can still be reminded or restricted. Each user is handled
// on its own, so a failure is counted and the run carries on. Safe to run concurrently:
// event idempotency keys allow one send per stage and one restriction event per cycle.
const runKycJob = async ({ now = new Date(), batchSize = 500 } = {}) => {
  const counts = { reminded: 0, skipped: 0, restricted: 0, failed: 0 };
  const settings = await KycSettings.getSettings();
  // Before launch nobody has a deadline, so there is nothing to remind or restrict.
  if (!isLaunched(settings)) return counts;
  let lastId = null;

  for (;;) {
    const filter = { 'kyc.status': { $in: SCANNED_STATUSES } };
    if (lastId) filter._id = { $gt: lastId };
    const batch = await AppUser.find(filter)
      .select('_id createdAt kyc')
      .sort({ _id: 1 })
      .limit(batchSize)
      .lean();
    if (!batch.length) break;
    lastId = batch[batch.length - 1]._id;

    for (const appUser of batch) {
      try {
        const state = computeKycState(appUser, settings, now);
        if (state.dueStage || state.skippedStages.length) {
          const r = await remindUser(appUser, state, now);
          counts.reminded += r.reminded;
          counts.skipped += r.skipped;
          counts.failed += r.failed;
        }
        if (state.restricted && !appUser.kyc?.restrictedAt) {
          if (await markRestricted(appUser, now)) counts.restricted += 1;
        }
      } catch (err) {
        logError('user failed', err);
        counts.failed += 1;
      }
    }

    if (batch.length < batchSize) break;
  }

  return counts;
};

// Takes or renews the job lease. Resolves false while another holder's lease is live.
const acquireLease = async (holder, now, ttlMs) => {
  try {
    const lock = await JobLock.findOneAndUpdate(
      { name: LOCK_NAME, $or: [{ expiresAt: { $lt: now } }, { holder }] },
      { $set: { holder, expiresAt: new Date(now.getTime() + ttlMs) } },
      { upsert: true, new: true }
    );
    return lock?.holder === holder;
  } catch (err) {
    // The upsert lost to an existing lock document: someone else holds the lease.
    if (isDuplicateKey(err)) return false;
    throw err;
  }
};

const releaseLease = (holder) => JobLock.deleteOne({ name: LOCK_NAME, holder });

// Runs the job every intervalMs on whichever instance holds the lease (2 x interval, so a
// dead holder is replaced within two intervals). Timers are unref'd so they never keep the
// process alive. Returns an async stop() that waits for a run in progress and frees the lease.
const startKycJob = ({
  intervalMs = Number(process.env.KYC_JOB_INTERVAL_MS) || DEFAULT_INTERVAL_MS,
  initialDelayMs = DEFAULT_INITIAL_DELAY_MS,
} = {}) => {
  const holder = `${os.hostname()}:${process.pid}:${crypto.randomBytes(6).toString('hex')}`;
  let running = null;
  let stopped = false;

  const runOnce = async () => {
    try {
      if (!(await acquireLease(holder, new Date(), 2 * intervalMs))) return;
      const counts = await runKycJob({ now: new Date() });
      if (Object.values(counts).some((n) => n > 0)) {
        console.info('KYC job run:', JSON.stringify(counts));
      }
    } catch (err) {
      logError('run failed', err);
    }
  };

  const tick = async () => {
    if (stopped || running) return;
    running = runOnce();
    try {
      await running;
    } finally {
      running = null;
    }
  };

  const first = setTimeout(tick, initialDelayMs);
  first.unref();
  const timer = setInterval(tick, intervalMs);
  timer.unref();

  return async () => {
    stopped = true;
    clearTimeout(first);
    clearInterval(timer);
    if (running) await running;
    await releaseLease(holder).catch((err) => logError('lease release failed', err));
  };
};

module.exports = { runKycJob, startKycJob, acquireLease, releaseLease };
