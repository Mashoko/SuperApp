const express = require('express');
const AppUser = require('../../models/app_user.model');
const KycSettings = require('../models/kyc_settings.model');
const KycDraft = require('../models/kyc_draft.model');
const KycDocument = require('../models/kyc_document.model');
const KycSubmission = require('../models/kyc_submission.model');
const KycEvent = require('../models/kyc_event.model');
const { requireAdmin } = require('../../middleware/auth.middleware');
const { KYC_STATUSES, RESTRICTABLE_STATUSES, computeKycState, DAY_MS } = require('../schedule');
const { kycKeyAvailable, decryptField, maskId } = require('../crypto');
const { readDecrypted, deleteStored } = require('../storage');
const { notify } = require('../notifications');

const { KYC_EVENT_TYPES } = KycEvent;

const router = express.Router();

const GENERIC = { message: 'Something went wrong.' };
const UNAVAILABLE = { message: 'KYC is temporarily unavailable.' };
const USER_NOT_FOUND = { message: 'User not found.' };
const DOC_NOT_FOUND = { message: 'Document not found.' };
const BAD_REASON = { message: 'Give a reason between 5 and 500 characters.' };
const NOT_PENDING = { message: 'This KYC is not waiting for review.' };
const NOT_APPROVED = { message: 'Only an approved KYC can be expired.' };
const NO_REMINDER = { message: 'This user does not need a reminder.' };
const RECENT_REMINDER = { message: 'A reminder was sent in the last hour.' };
const ALREADY_LAUNCHED = { message: 'KYC has already been launched.' };

const OBJECT_ID = /^[0-9a-f]{24}$/i;
const MAX_QUERY = 64;
const DEFAULT_LIMIT = 25;
const MAX_LIMIT = 100;
const AUDIT_PAGE_SIZE = 50;
const DETAIL_EVENTS = 100;
const MAX_EXEMPTION_DAYS = 90;
const REMIND_WINDOW_MS = 3600000;
const LIST_STATUSES = new Set([...KYC_STATUSES, 'RESTRICTED']);
const RESTRICTABLE = [...RESTRICTABLE_STATUSES];

const DAY_FIELDS = [
  'firstNudgeDays',
  'secondNudgeDays',
  'reminderIntervalDays',
  'warningBeforeDays',
  'enforcementDays',
  'resubmitGraceDays',
];
const SETTINGS_FIELDS = [...DAY_FIELDS, 'remindersEnabled'];

// Never sends or logs err.message: it can carry user data.
const handle = (fn) => async (req, res, next) => {
  try {
    await fn(req, res, next);
  } catch (err) {
    console.error('KYC admin route error:', err?.name, err?.code);
    res.status(500).json(GENERIC);
  }
};

const requireKycKey = (req, res, next) => {
  if (!kycKeyAvailable()) return res.status(503).json(UNAVAILABLE);
  next();
};

// Best effort: the action is already stored, so a notification failure is only logged.
const notifySafely = async (appUserId, kind, vars) => {
  try {
    await notify(appUserId, kind, vars);
  } catch (err) {
    console.error('KYC admin notification failed:', kind, err?.name, err?.code);
  }
};

const actorOf = (req) => req.user.username;

const record = (req, appUserId, type, data = {}) =>
  KycEvent.record({ appUserId, actor: actorOf(req), type, data });

// Trim, drop one trailing full stop, then require 5 to 500 characters. Null when invalid.
const cleanReason = (value) => {
  if (typeof value !== 'string') return null;
  let reason = value.trim();
  if (reason.endsWith('.')) reason = reason.slice(0, -1).trim();
  return reason.length >= 5 && reason.length <= 500 ? reason : null;
};

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const positiveInt = (value, fallback) => {
  const n = Number(value);
  return Number.isInteger(n) && n >= 1 ? n : fallback;
};

const loadUser = async (id) => (OBJECT_ID.test(id) ? AppUser.findById(id) : null);

// --- Serialisers ----------------------------------------------------------

const toRow = (user, settings, now) => {
  const state = computeKycState(user, settings, now);
  return {
    id: String(user._id),
    username: user.sipUsername,
    displayName: user.displayName || null,
    registeredAt: user.createdAt || null,
    status: state.status,
    underlyingStatus: state.underlyingStatus,
    submittedAt: user.kyc?.submittedAt || null,
    lastReminderAt: user.kyc?.lastReminderAt || null,
    deadline: state.deadline,
  };
};

const toDetail = (user, settings, now) => {
  const state = computeKycState(user, settings, now);
  const kyc = user.kyc || {};
  return {
    ...toRow(user, settings, now),
    cycle: kyc.cycle || 0,
    cycleStartedAt: kyc.cycleStartedAt || null,
    startedAt: kyc.startedAt || null,
    verifiedAt: kyc.verifiedAt || null,
    reviewedBy: kyc.reviewedBy || null,
    rejectionReason: kyc.rejectionReason || null,
    correctionNotes: kyc.correctionNotes || null,
    restrictedAt: kyc.restrictedAt || null,
    exemptUntil: state.exemptUntil,
    exemption: kyc.exemption?.until
      ? {
          until: kyc.exemption.until,
          reason: kyc.exemption.reason || null,
          grantedBy: kyc.exemption.grantedBy || null,
        }
      : null,
  };
};

const toDocDto = (d) => ({
  id: String(d._id),
  kind: d.kind,
  mime: d.mime,
  size: d.size,
  createdAt: d.createdAt,
});

const toEventDto = (e) => ({
  id: String(e._id),
  appUserId: e.appUserId ? String(e.appUserId) : null,
  type: e.type,
  actor: e.actor,
  data: e.data,
  createdAt: e.createdAt,
});

const toSubmissionDto = (s, docs, reveal) => {
  const enc = s.identification?.idNumberEnc;
  const plain = enc ? decryptField(enc) : null;
  const identification = {
    idType: s.identification?.idType || null,
    idExpiry: s.identification?.idExpiry || null,
    idNumberMasked: plain ? maskId(plain) : null,
  };
  if (reveal) identification.idNumber = plain;
  return {
    id: String(s._id),
    version: s.version,
    submittedAt: s.submittedAt,
    decision: s.decision,
    decidedBy: s.decidedBy || null,
    decidedAt: s.decidedAt || null,
    reason: s.reason || null,
    phone: s.phone,
    personal: s.personal || {},
    address: s.address || {},
    identification,
    documents: docs.map(toDocDto),
  };
};

const settingsDto = (s) => {
  const out = { rolloutAt: s.rolloutAt, updatedAt: s.updatedAt || null };
  for (const f of SETTINGS_FIELDS) out[f] = s[f];
  return out;
};

// --- Access ---------------------------------------------------------------

router.use(requireAdmin(['super_admin', 'kyc_reviewer']));

// --- Stats and search -----------------------------------------------------

// Users who could be restricted right now; the deadline check runs in code.
const restrictableFilter = { 'kyc.status': { $in: [null, ...RESTRICTABLE] } };

const findRestricted = async (filter, settings, now) => {
  const users = await AppUser.find({ $and: [filter, restrictableFilter] })
    .sort({ createdAt: -1, _id: -1 })
    .select('sipUsername displayName createdAt kyc');
  return users.filter((u) => computeKycState(u, settings, now).restricted);
};

router.get(
  '/stats',
  handle(async (req, res) => {
    const now = new Date();
    const [settings, groups] = await Promise.all([
      KycSettings.getSettings(),
      AppUser.aggregate([
        { $group: { _id: { $ifNull: ['$kyc.status', 'NOT_STARTED'] }, count: { $sum: 1 } } },
      ]),
    ]);
    const counts = Object.fromEntries(groups.map((g) => [g._id, g.count]));
    const restricted = await findRestricted({}, settings, now);
    return res.json({
      total: groups.reduce((sum, g) => sum + g.count, 0),
      approved: counts.APPROVED || 0,
      notStarted: counts.NOT_STARTED || 0,
      inProgress: counts.IN_PROGRESS || 0,
      pendingReview: counts.PENDING_REVIEW || 0,
      rejected: counts.REJECTED || 0,
      requiresCorrection: counts.REQUIRES_CORRECTION || 0,
      expired: counts.EXPIRED || 0,
      restricted: restricted.length,
    });
  })
);

router.get(
  '/users',
  handle(async (req, res) => {
    const { q, status } = req.query;
    if (q !== undefined && (typeof q !== 'string' || q.length > MAX_QUERY)) {
      return res.status(400).json({ message: `Search with ${MAX_QUERY} characters or fewer.` });
    }
    if (status !== undefined && (typeof status !== 'string' || !LIST_STATUSES.has(status))) {
      return res.status(400).json({ message: 'Choose a valid status.' });
    }
    const page = positiveInt(req.query.page, 1);
    const limit = Math.min(positiveInt(req.query.limit, DEFAULT_LIMIT), MAX_LIMIT);

    const clauses = [];
    const term = typeof q === 'string' ? q.trim() : '';
    if (term) {
      const pattern = new RegExp(escapeRegex(term), 'i');
      clauses.push({ $or: [{ sipUsername: pattern }, { displayName: pattern }] });
    }

    const now = new Date();
    const settings = await KycSettings.getSettings();
    let users;
    let total;
    if (status === 'RESTRICTED') {
      const all = await findRestricted(clauses.length ? { $and: clauses } : {}, settings, now);
      total = all.length;
      users = all.slice((page - 1) * limit, page * limit);
    } else {
      if (status === 'NOT_STARTED') clauses.push({ 'kyc.status': { $in: [null, 'NOT_STARTED'] } });
      else if (status) clauses.push({ 'kyc.status': status });
      const filter = clauses.length ? { $and: clauses } : {};
      [total, users] = await Promise.all([
        AppUser.countDocuments(filter),
        AppUser.find(filter)
          .sort({ createdAt: -1, _id: -1 })
          .skip((page - 1) * limit)
          .limit(limit)
          .select('sipUsername displayName createdAt kyc'),
      ]);
    }
    return res.json({
      items: users.map((u) => toRow(u, settings, now)),
      page,
      totalPages: Math.ceil(total / limit),
      total,
    });
  })
);

router.get(
  '/users/:id',
  requireKycKey,
  handle(async (req, res) => {
    const user = await loadUser(req.params.id);
    if (!user) return res.status(404).json(USER_NOT_FOUND);
    const reveal = req.query.reveal === '1';
    const now = new Date();
    const [settings, submissions, docs, events] = await Promise.all([
      KycSettings.getSettings(),
      KycSubmission.find({ appUserId: user._id }).sort({ version: -1 }),
      KycDocument.find({ appUserId: user._id, submissionId: { $ne: null } }).sort({ _id: 1 }),
      KycEvent.find({ appUserId: user._id }).sort({ createdAt: -1, _id: -1 }).limit(DETAIL_EVENTS),
    ]);
    const docsFor = (s) => docs.filter((d) => d.submissionId.equals(s._id));
    const submissionDtos = submissions.map((s) => toSubmissionDto(s, docsFor(s), reveal));
    if (reveal) {
      const revealed = submissions.filter((s) => s.identification?.idNumberEnc).map((s) => s._id);
      if (revealed.length) await record(req, user._id, 'ID_REVEALED', { submissionIds: revealed });
    }
    return res.json({
      user: toDetail(user, settings, now),
      submissions: submissionDtos,
      events: events.map(toEventDto),
    });
  })
);

router.get(
  '/documents/:id',
  requireKycKey,
  handle(async (req, res) => {
    const { id } = req.params;
    if (!OBJECT_ID.test(id)) return res.status(404).json(DOC_NOT_FOUND);
    const doc = await KycDocument.findById(id);
    if (!doc) return res.status(404).json(DOC_NOT_FOUND);
    let bytes;
    try {
      bytes = await readDecrypted(doc.storageKey);
    } catch (err) {
      return res.status(404).json(DOC_NOT_FOUND);
    }
    await record(req, doc.appUserId, 'DOCUMENT_VIEWED', { documentId: doc._id, kind: doc.kind });
    res.set({
      'Content-Type': doc.mime,
      'Cache-Control': 'no-store',
      'Content-Disposition': 'inline',
      'Content-Security-Policy': 'sandbox',
    });
    return res.send(bytes);
  })
);

// --- Decisions ------------------------------------------------------------

// 404 when the user does not exist, otherwise the given 409 body.
const conflictOrMissing = async (res, id, conflict) => {
  const exists = await AppUser.exists({ _id: id });
  if (!exists) return res.status(404).json(USER_NOT_FOUND);
  return res.status(409).json(conflict);
};

const decideLatestSubmission = (appUserId, decision, actor, now, reason) => {
  const $set = { decision, decidedBy: actor, decidedAt: now };
  if (reason) $set.reason = reason;
  return KycSubmission.findOneAndUpdate({ appUserId }, { $set }, { sort: { version: -1 }, new: true });
};

const deleteDraftAndDocuments = async (appUserId) => {
  await KycDraft.deleteOne({ appUserId });
  const docs = await KycDocument.find({ appUserId, submissionId: null });
  if (!docs.length) return;
  await KycDocument.deleteMany({ _id: { $in: docs.map((d) => d._id) }, submissionId: null });
  await Promise.all(docs.map((d) => deleteStored(d.storageKey).catch(() => {})));
};

// Replaces any draft with the submission's text fields (no documents: the user re-uploads).
const seedDraftFrom = async (appUserId, submission) => {
  if (!submission) return;
  const pick = (src, keys) => {
    const out = {};
    for (const k of keys) if (typeof src?.[k] === 'string' && src[k]) out[k] = src[k];
    return out;
  };
  const data = {
    personal: pick(submission.personal, ['firstName', 'lastName', 'dateOfBirth', 'gender', 'nationality']),
    address: pick(submission.address, ['line1', 'line2', 'city', 'country']),
    identification: pick(submission.identification, ['idType', 'idNumberEnc', 'idExpiry']),
  };
  await KycDraft.findOneAndUpdate({ appUserId }, { $set: { data } }, { upsert: true });
};

router.post(
  '/users/:id/approve',
  handle(async (req, res) => {
    const { id } = req.params;
    if (!OBJECT_ID.test(id)) return res.status(404).json(USER_NOT_FOUND);
    const now = new Date();
    const actor = actorOf(req);
    const before = await AppUser.findOneAndUpdate(
      { _id: id, 'kyc.status': 'PENDING_REVIEW' },
      {
        $set: {
          'kyc.status': 'APPROVED',
          'kyc.verifiedAt': now,
          'kyc.reviewedBy': actor,
          'kyc.lastUpdatedAt': now,
        },
        $unset: {
          'kyc.exemption': 1,
          'kyc.restrictedAt': 1,
          'kyc.rejectionReason': 1,
          'kyc.correctionNotes': 1,
        },
      },
      { returnDocument: 'before' }
    );
    if (!before) return conflictOrMissing(res, id, NOT_PENDING);

    const submission = await decideLatestSubmission(before._id, 'approved', actor, now);
    await deleteDraftAndDocuments(before._id);
    await record(req, before._id, 'APPROVED', {
      submissionId: submission?._id || null,
      version: submission?.version || null,
    });
    if (before.kyc?.restrictedAt) {
      await record(req, before._id, 'UNRESTRICTED', { reason: 'approved' });
    }
    await notifySafely(before._id, 'APPROVED');
    return res.json({ status: 'APPROVED', verifiedAt: now });
  })
);

// Reject, request correction and expire all start a new cycle with a fresh grace period.
const newCycleAction = ({ from, to, decision, eventType, notifyKind, reasonField, conflict }) =>
  handle(async (req, res) => {
    const { id } = req.params;
    if (!OBJECT_ID.test(id)) return res.status(404).json(USER_NOT_FOUND);
    const reason = cleanReason(req.body?.reason);
    if (!reason) return res.status(400).json(BAD_REASON);

    const now = new Date();
    const actor = actorOf(req);
    const $set = {
      'kyc.status': to,
      'kyc.cycleStartedAt': now,
      'kyc.lastReminderStage': null,
      'kyc.restrictedAt': null,
      'kyc.lastUpdatedAt': now,
      'kyc.reviewedBy': actor,
    };
    const $unset = { 'kyc.rejectionReason': 1, 'kyc.correctionNotes': 1 };
    if (reasonField) {
      $set[`kyc.${reasonField}`] = reason;
      delete $unset[`kyc.${reasonField}`];
    }
    const updated = await AppUser.findOneAndUpdate(
      { _id: id, 'kyc.status': from },
      { $set, $unset, $inc: { 'kyc.cycle': 1 } },
      { new: true }
    );
    if (!updated) return conflictOrMissing(res, id, conflict);

    const submission = await decideLatestSubmission(updated._id, decision, actor, now, reason);
    await seedDraftFrom(updated._id, submission);
    await record(req, updated._id, eventType, {
      reason,
      cycle: updated.kyc.cycle,
      submissionId: submission?._id || null,
    });

    const settings = await KycSettings.getSettings();
    const { deadline } = computeKycState(updated, settings, now);
    await notifySafely(updated._id, notifyKind, { reason, deadline });
    return res.json({ status: to, cycle: updated.kyc.cycle, deadline });
  });

router.post(
  '/users/:id/reject',
  newCycleAction({
    from: 'PENDING_REVIEW',
    to: 'REJECTED',
    decision: 'rejected',
    eventType: 'REJECTED',
    notifyKind: 'REJECTED',
    reasonField: 'rejectionReason',
    conflict: NOT_PENDING,
  })
);

router.post(
  '/users/:id/request-correction',
  newCycleAction({
    from: 'PENDING_REVIEW',
    to: 'REQUIRES_CORRECTION',
    decision: 'correction_requested',
    eventType: 'CORRECTION_REQUESTED',
    notifyKind: 'CORRECTION_REQUESTED',
    reasonField: 'correctionNotes',
    conflict: NOT_PENDING,
  })
);

router.post(
  '/users/:id/expire',
  newCycleAction({
    from: 'APPROVED',
    to: 'EXPIRED',
    decision: 'expired',
    eventType: 'EXPIRED',
    notifyKind: 'EXPIRED',
    reasonField: null,
    conflict: NOT_APPROVED,
  })
);

router.post(
  '/users/:id/exemption',
  handle(async (req, res) => {
    const { id } = req.params;
    if (!OBJECT_ID.test(id)) return res.status(404).json(USER_NOT_FOUND);
    const raw = req.body?.until;
    const until = typeof raw === 'string' ? new Date(raw) : null;
    const now = Date.now();
    if (
      !until ||
      Number.isNaN(until.getTime()) ||
      until.getTime() <= now ||
      until.getTime() > now + MAX_EXEMPTION_DAYS * DAY_MS
    ) {
      return res
        .status(400)
        .json({ message: `Choose an end date in the next ${MAX_EXEMPTION_DAYS} days.` });
    }
    const reason = cleanReason(req.body?.reason);
    if (!reason) return res.status(400).json(BAD_REASON);

    const actor = actorOf(req);
    const updated = await AppUser.findOneAndUpdate(
      { _id: id },
      {
        $set: {
          'kyc.exemption': { until, reason, grantedBy: actor },
          'kyc.lastUpdatedAt': new Date(now),
        },
      },
      { new: true }
    );
    if (!updated) return res.status(404).json(USER_NOT_FOUND);
    await record(req, updated._id, 'EXEMPTION_GRANTED', { until, reason });
    return res.json({ exemption: { until, reason, grantedBy: actor } });
  })
);

// The reminder is the action itself, so a notification failure fails the request
// (and records nothing) instead of being swallowed.
router.post(
  '/users/:id/remind',
  handle(async (req, res) => {
    const user = await loadUser(req.params.id);
    if (!user) return res.status(404).json(USER_NOT_FOUND);
    const now = new Date();
    const settings = await KycSettings.getSettings();
    const state = computeKycState(user, settings, now);
    if (!RESTRICTABLE_STATUSES.has(state.underlyingStatus) || !state.deadline) {
      return res.status(409).json(NO_REMINDER);
    }
    const last = await KycEvent.findOne({ appUserId: user._id, type: 'MANUAL_REMINDER' })
      .sort({ createdAt: -1 })
      .select('createdAt');
    if (last && now.getTime() - last.createdAt.getTime() < REMIND_WINDOW_MS) {
      return res.status(409).json(RECENT_REMINDER);
    }
    await notify(user._id, 'REMINDER', { deadline: state.deadline });
    await AppUser.updateOne({ _id: user._id }, { $set: { 'kyc.lastReminderAt': now } });
    await record(req, user._id, 'MANUAL_REMINDER', { deadline: state.deadline });
    return res.json({ sentAt: now });
  })
);

// --- Settings -------------------------------------------------------------

const validateSettings = (s) => {
  for (const f of DAY_FIELDS) {
    if (!Number.isInteger(s[f]) || s[f] < 1 || s[f] > 365) {
      return `${f} must be a whole number from 1 to 365.`;
    }
  }
  if (typeof s.remindersEnabled !== 'boolean') return 'remindersEnabled must be true or false.';
  if (s.secondNudgeDays <= s.firstNudgeDays) {
    return 'The second nudge must come after the first.';
  }
  if (s.warningBeforeDays >= s.enforcementDays) {
    return 'The warning must come before the enforcement deadline.';
  }
  if (s.resubmitGraceDays <= s.warningBeforeDays) {
    return 'The resubmission grace period must be longer than the warning period.';
  }
  return null;
};

router.get(
  '/settings',
  handle(async (req, res) => {
    const settings = await KycSettings.getSettings();
    return res.json(settingsDto(settings));
  })
);

router.put(
  '/settings',
  requireAdmin(['super_admin']),
  handle(async (req, res) => {
    const body = req.body;
    if (body === null || typeof body !== 'object' || Array.isArray(body)) {
      return res.status(400).json({ message: 'Send the settings to change.' });
    }
    const unknown = Object.keys(body).filter((k) => !SETTINGS_FIELDS.includes(k));
    if (unknown.length) {
      return res.status(400).json({ message: 'Only reminder and deadline settings can be changed.' });
    }
    const current = await KycSettings.getSettings();
    const merged = {};
    for (const f of SETTINGS_FIELDS) merged[f] = body[f] !== undefined ? body[f] : current[f];
    const error = validateSettings(merged);
    if (error) return res.status(400).json({ message: error });

    const before = {};
    const after = {};
    for (const f of SETTINGS_FIELDS) {
      if (merged[f] !== current[f]) {
        before[f] = current[f];
        after[f] = merged[f];
      }
    }
    if (!Object.keys(after).length) return res.json(settingsDto(current));

    const updated = await KycSettings.findOneAndUpdate(
      { _id: current._id },
      { $set: after },
      { new: true, runValidators: true }
    );
    await record(req, null, 'SETTINGS_CHANGED', { before, after });
    return res.json(settingsDto(updated));
  })
);

// Starts the KYC clock for everyone. Set once: rolloutAt is only written while it is null.
// Refused without the encryption key, since users could not complete KYC.
router.post(
  '/settings/launch',
  requireAdmin(['super_admin']),
  requireKycKey,
  handle(async (req, res) => {
    const current = await KycSettings.getSettings();
    const rolloutAt = new Date();
    const updated = await KycSettings.findOneAndUpdate(
      { _id: current._id, rolloutAt: null },
      { $set: { rolloutAt } },
      { new: true }
    );
    if (!updated) return res.status(409).json(ALREADY_LAUNCHED);
    await record(req, null, 'SETTINGS_CHANGED', {
      before: { rolloutAt: null },
      after: { rolloutAt },
    });
    return res.json(settingsDto(updated));
  })
);

// --- Audit ----------------------------------------------------------------

router.get(
  '/audit',
  handle(async (req, res) => {
    const { appUserId, type } = req.query;
    const filter = {};
    if (appUserId !== undefined) {
      if (typeof appUserId !== 'string' || !OBJECT_ID.test(appUserId)) {
        return res.status(400).json({ message: 'Choose a valid user.' });
      }
      filter.appUserId = appUserId;
    }
    if (type !== undefined) {
      if (typeof type !== 'string' || !KYC_EVENT_TYPES.includes(type)) {
        return res.status(400).json({ message: 'Choose a valid event type.' });
      }
      filter.type = type;
    }
    const page = positiveInt(req.query.page, 1);
    const [total, events] = await Promise.all([
      KycEvent.countDocuments(filter),
      KycEvent.find(filter)
        .sort({ createdAt: -1, _id: -1 })
        .skip((page - 1) * AUDIT_PAGE_SIZE)
        .limit(AUDIT_PAGE_SIZE),
    ]);
    return res.json({
      items: events.map(toEventDto),
      page,
      totalPages: Math.ceil(total / AUDIT_PAGE_SIZE),
      total,
    });
  })
);

module.exports = router;
