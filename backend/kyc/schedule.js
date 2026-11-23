// Pure KYC scheduling core. No DB or I/O; every function takes `now` explicitly.
// All arithmetic is in UTC milliseconds.

const DAY_MS = 86400000;

const KYC_STATUSES = [
  'NOT_STARTED',
  'IN_PROGRESS',
  'PENDING_REVIEW',
  'APPROVED',
  'REJECTED',
  'REQUIRES_CORRECTION',
  'EXPIRED',
];

const RESTRICTABLE_STATUSES = new Set([
  'NOT_STARTED',
  'IN_PROGRESS',
  'REJECTED',
  'REQUIRES_CORRECTION',
  'EXPIRED',
]);

// Statuses with no deadline, no restriction and no reminders.
const SETTLED_STATUSES = new Set(['APPROVED', 'PENDING_REVIEW']);

const addDays = (date, days) => new Date(date.getTime() + days * DAY_MS);

const toDate = (value) => {
  if (value == null) return null;
  const d = value instanceof Date ? value : new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
};

const readKyc = (appUser) => {
  const kyc = (appUser && appUser.kyc) || {};
  return {
    status: kyc.status || 'NOT_STARTED',
    cycle: Number(kyc.cycle) || 0,
    cycleStartedAt: toDate(kyc.cycleStartedAt),
    lastReminderStage: kyc.lastReminderStage || null,
    exemptionUntil: toDate(kyc.exemption && kyc.exemption.until),
  };
};

// Start of the cycle-0 clock: max(createdAt, rolloutAt).
const initialClockStart = (appUser, settings) => {
  const created = toDate(appUser && appUser.createdAt);
  const rollout = toDate(settings.rolloutAt);
  if (created && rollout) return created > rollout ? created : rollout;
  return created || rollout;
};

// KYC is launched once rolloutAt is set. Before that nobody has a deadline.
const isLaunched = (settings) => !!toDate(settings && settings.rolloutAt);

// Returns { clockStart, deadline } for the user's current cycle.
// A cycle >= 1 without cycleStartedAt falls back to the cycle-0 clock. A cycle started
// before launch counts from rolloutAt, so a pre-launch decision cannot restrict at launch.
const cycleWindow = (appUser, settings) => {
  if (!isLaunched(settings)) return { cycle: 0, clockStart: null, deadline: null };
  const { cycle, cycleStartedAt } = readKyc(appUser);
  if (cycle >= 1 && cycleStartedAt) {
    const rollout = toDate(settings.rolloutAt);
    const clockStart = cycleStartedAt > rollout ? cycleStartedAt : rollout;
    return {
      cycle,
      clockStart,
      deadline: addDays(clockStart, settings.resubmitGraceDays),
    };
  }
  const clockStart = initialClockStart(appUser, settings);
  return {
    cycle: 0,
    clockStart,
    deadline: clockStart ? addDays(clockStart, settings.enforcementDays) : null,
  };
};

const reminderSchedule = (appUser, settings) => {
  const { cycle, clockStart, deadline } = cycleWindow(appUser, settings);
  if (!clockStart || !deadline) return [];

  // The schedule is strictly increasing in time. Pre-warning stages must land
  // before both the warning and the deadline; a stage at or before the previous
  // kept stage is dropped.
  const warningAt = addDays(deadline, -settings.warningBeforeDays);
  const hasWarning = warningAt < deadline;
  const preWarningLimit = hasWarning ? warningAt : deadline;
  const stages = [];
  const push = (stage, at) => {
    const prev = stages[stages.length - 1];
    if (at >= preWarningLimit) return false;
    if (prev && at <= prev.at) return true;
    stages.push({ stage, at });
    return true;
  };

  if (cycle === 0) {
    push('NUDGE_1', addDays(clockStart, settings.firstNudgeDays));
    push('NUDGE_2', addDays(clockStart, settings.secondNudgeDays));
  }

  const interval = settings.reminderIntervalDays;
  if (interval > 0) {
    for (let k = 1; ; k += 1) {
      if (!push(`REMINDER_${k}`, addDays(clockStart, k * interval))) break;
    }
  }

  // Every kept stage is before warningAt, so WARNING keeps the order strict.
  if (hasWarning) stages.push({ stage: 'WARNING', at: warningAt });
  // RESTRICTED is always the final entry; anything at or after it gives way.
  while (stages.length && stages[stages.length - 1].at >= deadline) stages.pop();
  stages.push({ stage: 'RESTRICTED', at: deadline });
  return stages;
};

const computeKycState = (appUser, settings, now) => {
  const kyc = readKyc(appUser);
  const underlyingStatus = kyc.status;
  const exemptUntil = kyc.exemptionUntil && kyc.exemptionUntil > now ? kyc.exemptionUntil : null;

  if (SETTLED_STATUSES.has(underlyingStatus) || !isLaunched(settings)) {
    return {
      status: underlyingStatus,
      underlyingStatus,
      restricted: false,
      deadline: null,
      exemptUntil,
      dueStage: null,
      skippedStages: [],
    };
  }

  const { deadline } = cycleWindow(appUser, settings);
  const restricted =
    RESTRICTABLE_STATUSES.has(underlyingStatus) && !!deadline && now >= deadline && !exemptUntil;

  let dueStage = null;
  let skippedStages = [];
  if (settings.remindersEnabled) {
    const schedule = reminderSchedule(appUser, settings);
    const sentIdx = kyc.lastReminderStage
      ? schedule.findIndex((s) => s.stage === kyc.lastReminderStage)
      : -1;
    // While an exemption is active the RESTRICTED notice is held back (not
    // skipped), so it fires once the exemption lapses and restriction begins.
    const end = exemptUntil ? schedule.length - 1 : schedule.length;
    let dueIdx = -1;
    for (let i = sentIdx + 1; i < end; i += 1) {
      if (schedule[i].at <= now) dueIdx = i;
      else break;
    }
    if (dueIdx > sentIdx) {
      dueStage = schedule[dueIdx].stage;
      skippedStages = schedule.slice(sentIdx + 1, dueIdx).map((s) => s.stage);
    }
  }

  return {
    status: restricted ? 'RESTRICTED' : underlyingStatus,
    underlyingStatus,
    restricted,
    deadline,
    exemptUntil,
    dueStage,
    skippedStages,
  };
};

module.exports = {
  DAY_MS,
  KYC_STATUSES,
  RESTRICTABLE_STATUSES,
  computeKycState,
  isLaunched,
  reminderSchedule,
};
