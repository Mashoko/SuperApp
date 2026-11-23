const express = require('express');
const multer = require('multer');
const AppUser = require('../../models/app_user.model');
const KycSettings = require('../models/kyc_settings.model');
const KycDraft = require('../models/kyc_draft.model');
const KycDocument = require('../models/kyc_document.model');
const KycSubmission = require('../models/kyc_submission.model');
const KycEvent = require('../models/kyc_event.model');
const { resolveUser } = require('../../middleware/resolve_user.middleware');
const { kycUploadLimiter } = require('../../middleware/rate_limits');
const { computeKycState, isLaunched } = require('../schedule');
const { kycKeyAvailable, encryptField, decryptField, maskId } = require('../crypto');
const { sniffType, stripMetadata } = require('../files');
const { notify } = require('../notifications');
const { saveEncrypted, readDecrypted, deleteStored } = require('../storage');
const {
  DRAFT_FIELDS,
  ID_TYPES,
  validateDraft,
  validateSubmission,
  requiredDocumentKinds,
} = require('../validation');

const { KYC_DOCUMENT_KINDS } = KycDocument;

const router = express.Router();

const SIGN_IN = { message: 'Sign in required.' };
const UNAVAILABLE = { message: 'KYC is temporarily unavailable.' };
const ALREADY_SUBMITTED = { message: 'Your KYC is already submitted.' };
const NOT_FOUND = { message: 'Document not found.' };
const BAD_TYPE = { message: 'Upload a JPEG, PNG or PDF file.' };
const TOO_LARGE = { message: 'File is too large.' };
const GENERIC = { message: 'Something went wrong.' };
const DOCS_CHANGED = { message: 'Your documents changed while submitting. Please try again.' };

const SUBMITTED_STATUSES = ['PENDING_REVIEW', 'APPROVED'];
const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'application/pdf']);
const UNREADABLE = 'Unreadable image file.';
const OBJECT_ID = /^[0-9a-f]{24}$/i;
const SECTIONS = ['personal', 'address', 'identification'];

const isPlainObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const isSubmitted = (appUser) => SUBMITTED_STATUSES.includes(appUser.kyc?.status);

// Never sends or logs err.message: it can carry user data.
const fail = (res, err) => {
  console.error('KYC route error:', err?.name, err?.code);
  return res.status(500).json(GENERIC);
};

const handle = (fn) => async (req, res, next) => {
  try {
    await fn(req, res, next);
  } catch (err) {
    fail(res, err);
  }
};

// --- Access ---------------------------------------------------------------

const requireTokenAuth = (req, res, next) => {
  if (req.auth?.via !== 'token') return res.status(401).json(SIGN_IN);
  next();
};

const requireKycKey = (req, res, next) => {
  if (!kycKeyAvailable()) return res.status(503).json(UNAVAILABLE);
  next();
};

// Loads the AppUser by the token's subject, never by username.
const loadAppUser = handle(async (req, res, next) => {
  const id = req.auth.appUserId;
  if (typeof id !== 'string' || !OBJECT_ID.test(id)) return res.status(401).json(SIGN_IN);
  const appUser = await AppUser.findById(id);
  if (!appUser || appUser.sipUsername !== req.userId) return res.status(401).json(SIGN_IN);
  req.kycUser = appUser;
  next();
});

router.use(resolveUser({ field: 'userId' }), requireTokenAuth, requireKycKey, loadAppUser);

// --- Serialisers ----------------------------------------------------------

const toDocDto = (d) => ({
  id: String(d._id),
  kind: d.kind,
  mime: d.mime,
  size: d.size,
  createdAt: d.createdAt,
});

const pickFields = (source, fields) => {
  const out = {};
  const src = isPlainObject(source) ? source : {};
  for (const field of fields) {
    if (typeof src[field] === 'string' && src[field]) out[field] = src[field];
  }
  return out;
};

// Draft as stored, with the ID number decrypted. Server-side use only.
const plainDraftData = (draft) => {
  const data = (draft && draft.data) || {};
  const identification = pickFields(data.identification, ['idType', 'idExpiry']);
  const enc = data.identification?.idNumberEnc;
  if (enc) identification.idNumber = decryptField(enc);
  return {
    personal: pickFields(data.personal, Object.keys(DRAFT_FIELDS.personal)),
    address: pickFields(data.address, Object.keys(DRAFT_FIELDS.address)),
    identification,
  };
};

// Draft for the client: ID number masked, never plaintext.
const toDraftDto = (draft) => {
  if (!draft) return null;
  const data = draft.data || {};
  const enc = data.identification?.idNumberEnc;
  return {
    personal: pickFields(data.personal, Object.keys(DRAFT_FIELDS.personal)),
    address: pickFields(data.address, Object.keys(DRAFT_FIELDS.address)),
    identification: {
      ...pickFields(data.identification, ['idType', 'idExpiry']),
      idNumberMasked: enc ? maskId(decryptField(enc)) : null,
    },
    updatedAt: draft.updatedAt,
  };
};

// Field-level merge: an omitted field keeps its saved value, null or '' clears it.
// The ID number is encrypted here and the plaintext dropped.
const mergeDraftData = (existing, incoming) => {
  const out = {};
  for (const [section, fields] of Object.entries(DRAFT_FIELDS)) {
    const prev = isPlainObject(existing?.[section]) ? existing[section] : {};
    const next = isPlainObject(incoming[section]) ? incoming[section] : {};
    const merged = {};
    for (const field of Object.keys(fields)) {
      if (section === 'identification' && field === 'idNumber') continue;
      const value = next[field] !== undefined ? next[field] : prev[field];
      if (typeof value === 'string' && value.trim()) merged[field] = value.trim();
    }
    if (section === 'identification') {
      const idNumber = next.idNumber;
      if (idNumber === undefined) {
        if (prev.idNumberEnc) merged.idNumberEnc = prev.idNumberEnc;
      } else if (typeof idNumber === 'string' && idNumber.trim()) {
        merged.idNumberEnc = encryptField(idNumber.trim().toUpperCase());
      }
    }
    out[section] = merged;
  }
  return out;
};

// 20 points each for personal, address, identification, documents and review.
const computeProgress = (underlyingStatus, draft, docs) => {
  if (SUBMITTED_STATUSES.includes(underlyingStatus)) return { progress: 100, outstanding: [] };
  const plain = plainDraftData(draft);
  const outstanding = Object.keys(validateSubmission(plain, docs).errors);
  const sectionDone = (prefix) => !outstanding.some((k) => k.startsWith(`${prefix}.`));
  let progress = 0;
  for (const section of SECTIONS) if (sectionDone(section)) progress += 20;
  if (ID_TYPES.includes(plain.identification.idType) && sectionDone('documents')) progress += 20;
  return { progress, outstanding };
};

// --- Routes ---------------------------------------------------------------

router.get(
  '/me',
  handle(async (req, res) => {
    const appUser = req.kycUser;
    const settings = await KycSettings.getSettings();
    const state = computeKycState(appUser, settings, new Date());
    const [draft, docs, submissions] = await Promise.all([
      KycDraft.findOne({ appUserId: appUser._id }),
      KycDocument.find({ appUserId: appUser._id, submissionId: null }).sort({ _id: 1 }),
      KycSubmission.find({ appUserId: appUser._id })
        .sort({ version: 1 })
        .select('version submittedAt decision decidedAt reason'),
    ]);
    const { progress, outstanding } = computeProgress(state.underlyingStatus, draft, docs);
    return res.json({
      status: state.status,
      underlyingStatus: state.underlyingStatus,
      launched: isLaunched(settings),
      deadline: state.deadline,
      exemptUntil: state.exemptUntil,
      progress,
      outstanding,
      draft: toDraftDto(draft),
      documents: docs.map(toDocDto),
      history: submissions.map((s) => ({
        version: s.version,
        submittedAt: s.submittedAt,
        decision: s.decision,
        decidedAt: s.decidedAt || null,
        reason: s.reason || null,
      })),
      rejectionReason: appUser.kyc?.rejectionReason || null,
      correctionNotes: appUser.kyc?.correctionNotes || null,
      phone: req.userId,
    });
  })
);

const upsertDraft = async (appUserId, data) => {
  const run = () =>
    KycDraft.findOneAndUpdate(
      { appUserId },
      { $set: { data } },
      { upsert: true, new: true, includeResultMetadata: true }
    );
  let result;
  try {
    result = await run();
  } catch (err) {
    // A concurrent first save can lose the upsert race on the unique index; retry as an update.
    if (err?.code !== 11000) throw err;
    result = await run();
  }
  return { draft: result.value, inserted: !result.lastErrorObject?.updatedExisting };
};

router.put(
  '/draft',
  handle(async (req, res) => {
    const appUser = req.kycUser;
    if (isSubmitted(appUser)) return res.status(409).json(ALREADY_SUBMITTED);

    const incoming = req.body?.data;
    const { ok, errors } = validateDraft(incoming);
    if (!ok) return res.status(400).json({ message: 'Some details are invalid.', errors });

    const existing = await KycDraft.findOne({ appUserId: appUser._id });
    const data = mergeDraftData(existing?.data, incoming);
    const { draft, inserted } = await upsertDraft(appUser._id, data);

    const now = new Date();
    // null also matches AppUsers stored before the kyc subdocument existed (NOT_STARTED).
    await AppUser.updateOne(
      { _id: appUser._id, 'kyc.status': { $in: ['NOT_STARTED', null] } },
      { $set: { 'kyc.status': 'IN_PROGRESS', 'kyc.startedAt': now, 'kyc.lastUpdatedAt': now } }
    );
    const updated = await AppUser.findOneAndUpdate(
      { _id: appUser._id },
      { $set: { 'kyc.lastUpdatedAt': now } },
      { new: true }
    );
    if (inserted) {
      await KycEvent.record({ appUserId: appUser._id, type: 'DRAFT_SAVED', data: {} });
    }
    return res.json({ status: updated?.kyc?.status, draft: toDraftDto(draft) });
  })
);

// Read per request so the limit can be changed without a restart (and in tests).
const maxUploadBytes = () => {
  const mb = Number(process.env.KYC_MAX_UPLOAD_MB);
  return Math.floor((Number.isFinite(mb) && mb > 0 ? mb : 8) * 1024 * 1024);
};

// Memory storage only: KYC files must never touch disk unencrypted.
const receiveFile = (req, res, next) => {
  const parse = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: maxUploadBytes(), files: 1, fields: 5, fieldSize: 1024 },
  }).single('file');
  parse(req, res, (err) => {
    if (!err) return next();
    if (err.code === 'LIMIT_FILE_SIZE') return res.status(413).json(TOO_LARGE);
    return res.status(400).json({ message: 'Choose one file to upload.' });
  });
};

router.post(
  '/documents',
  kycUploadLimiter,
  receiveFile,
  handle(async (req, res) => {
    const appUser = req.kycUser;
    const kind = req.body?.kind;
    if (!KYC_DOCUMENT_KINDS.includes(kind)) {
      return res.status(400).json({ message: 'Choose a valid document type.' });
    }
    if (!req.file?.buffer?.length) {
      return res.status(400).json({ message: 'Choose one file to upload.' });
    }
    if (isSubmitted(appUser)) return res.status(409).json(ALREADY_SUBMITTED);

    // Order matters: sniff the real type, strip metadata, then hash and encrypt the clean bytes.
    const mime = sniffType(req.file.buffer);
    if (!mime || !ALLOWED_MIME.has(mime)) return res.status(415).json(BAD_TYPE);
    let clean;
    try {
      clean = stripMetadata(req.file.buffer, mime);
    } catch (err) {
      if (err?.message === UNREADABLE) return res.status(415).json(BAD_TYPE);
      throw err;
    }

    const stored = await saveEncrypted(clean);
    let doc;
    try {
      doc = await KycDocument.create({
        appUserId: appUser._id,
        kind,
        storageKey: stored.storageKey,
        mime,
        size: stored.size,
        sha256: stored.sha256,
        submissionId: null,
      });
    } catch (err) {
      await deleteStored(stored.storageKey).catch(() => {});
      throw err;
    }

    // Replace older draft documents of the same kind. Only ids below the new one, so
    // with concurrent uploads the newest survives.
    const older = await KycDocument.find({
      appUserId: appUser._id,
      kind,
      submissionId: null,
      _id: { $lt: doc._id },
    });
    if (older.length) {
      await KycDocument.deleteMany({ _id: { $in: older.map((d) => d._id) } });
      await Promise.all(older.map((d) => deleteStored(d.storageKey).catch(() => {})));
    }

    await KycEvent.record({
      appUserId: appUser._id,
      type: 'DOCUMENT_UPLOADED',
      data: { documentId: doc._id, kind, mime, size: doc.size, replaced: older.length },
    });
    return res.status(201).json(toDocDto(doc));
  })
);

router.get(
  '/documents/:id',
  handle(async (req, res) => {
    const { id } = req.params;
    if (!OBJECT_ID.test(id)) return res.status(404).json(NOT_FOUND);
    const doc = await KycDocument.findOne({ _id: id, appUserId: req.kycUser._id });
    if (!doc) return res.status(404).json(NOT_FOUND);
    let bytes;
    try {
      bytes = await readDecrypted(doc.storageKey);
    } catch (err) {
      return res.status(404).json(NOT_FOUND);
    }
    res.set({
      'Content-Type': doc.mime,
      'Cache-Control': 'no-store',
      'Content-Disposition': 'inline',
      'Content-Security-Policy': 'sandbox',
    });
    return res.send(bytes);
  })
);

router.delete(
  '/documents/:id',
  handle(async (req, res) => {
    const { id } = req.params;
    if (!OBJECT_ID.test(id)) return res.status(404).json(NOT_FOUND);
    const doc = await KycDocument.findOneAndDelete({
      _id: id,
      appUserId: req.kycUser._id,
      submissionId: null,
    });
    if (!doc) return res.status(404).json(NOT_FOUND);
    await deleteStored(doc.storageKey).catch(() => {});
    return res.status(204).end();
  })
);

router.post(
  '/submit',
  handle(async (req, res) => {
    const appUser = req.kycUser;
    if (isSubmitted(appUser)) return res.status(409).json(ALREADY_SUBMITTED);

    const [draft, docs] = await Promise.all([
      KycDraft.findOne({ appUserId: appUser._id }),
      KycDocument.find({ appUserId: appUser._id, submissionId: null }).sort({ _id: 1 }),
    ]);
    const plain = plainDraftData(draft);
    const { ok, errors } = validateSubmission(plain, docs);
    if (!ok) {
      return res.status(400).json({ message: 'Some details are missing or invalid.', errors });
    }

    const last = await KycSubmission.findOne({ appUserId: appUser._id })
      .sort({ version: -1 })
      .select('version');
    const version = (last?.version || 0) + 1;
    const now = new Date();
    // Link only the newest document of each required kind; other draft documents are
    // removed after a successful submit.
    const latestByKind = new Map();
    for (const d of docs) latestByKind.set(d.kind, d);
    const linked = requiredDocumentKinds(plain.identification.idType).map((k) => latestByKind.get(k));
    const documentIds = linked.map((d) => d._id);
    const leftovers = docs.filter((d) => !documentIds.some((id) => id.equals(d._id)));

    let submission;
    try {
      submission = await KycSubmission.create({
        appUserId: appUser._id,
        version,
        personal: plain.personal,
        address: plain.address,
        identification: {
          idType: plain.identification.idType,
          idNumberEnc: draft.data.identification.idNumberEnc,
          idExpiry: plain.identification.idExpiry,
        },
        phone: req.userId,
        documentIds,
        submittedAt: now,
        decision: 'pending',
      });
    } catch (err) {
      // A concurrent submit already took this version.
      if (err?.code === 11000) return res.status(409).json(ALREADY_SUBMITTED);
      throw err;
    }

    const rollback = async () => {
      await KycDocument.updateMany(
        { submissionId: submission._id },
        { $set: { submissionId: null } }
      );
      await KycSubmission.deleteOne({ _id: submission._id });
    };

    // Claim the documents before changing status. A concurrent upload replacement or
    // delete only touches rows with submissionId null, so a short count means one vanished.
    const link = await KycDocument.updateMany(
      { _id: { $in: documentIds }, appUserId: appUser._id, submissionId: null },
      { $set: { submissionId: submission._id } }
    );
    if (link.modifiedCount !== documentIds.length) {
      await rollback();
      return res.status(409).json(DOCS_CHANGED);
    }

    const before = await AppUser.findOneAndUpdate(
      { _id: appUser._id, 'kyc.status': { $nin: SUBMITTED_STATUSES } },
      {
        $set: {
          'kyc.status': 'PENDING_REVIEW',
          'kyc.submittedAt': now,
          'kyc.lastUpdatedAt': now,
        },
        $unset: { 'kyc.restrictedAt': 1 },
      },
      { returnDocument: 'before' }
    );
    if (!before) {
      await rollback();
      return res.status(409).json(ALREADY_SUBMITTED);
    }

    if (leftovers.length) {
      await KycDocument.deleteMany({
        _id: { $in: leftovers.map((d) => d._id) },
        submissionId: null,
      });
      await Promise.all(leftovers.map((d) => deleteStored(d.storageKey).catch(() => {})));
    }

    await KycEvent.record({
      appUserId: appUser._id,
      type: 'SUBMITTED',
      data: { submissionId: submission._id, version, documentCount: documentIds.length },
    });
    if (before.kyc?.restrictedAt) {
      await KycEvent.record({
        appUserId: appUser._id,
        type: 'UNRESTRICTED',
        data: { reason: 'submitted', submissionId: submission._id },
      });
    }
    await KycDraft.deleteOne({ appUserId: appUser._id });

    // Best effort: the submission is already stored, so a notification failure is only logged.
    try {
      await notify(appUser._id, 'SUBMITTED');
    } catch (err) {
      console.error('KYC submitted notification failed:', err?.name, err?.code);
    }

    return res.status(201).json({ status: 'PENDING_REVIEW', submittedAt: now });
  })
);

module.exports = router;
