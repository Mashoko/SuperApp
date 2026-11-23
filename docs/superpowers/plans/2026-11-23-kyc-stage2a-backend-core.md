# KYC Stage 2a: Backend KYC Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the backend a complete KYC engine: status lifecycle, configurable reminder and deadline schedule, encrypted document storage, user KYC API, server-side restriction of protected routes, a reminder job with in-app notifications, and the admin review API.

**Architecture:** All KYC code lives under `backend/kyc/` (models, pure schedule logic, crypto/storage, routes, job). Access state (restricted or not, deadline, due reminder) is computed by one pure function from the user's KYC record, the settings singleton, and `now`, so settings changes apply to everyone without rewriting rows and tests use a controlled clock. `requireKycAccess` runs after Stage 1's `resolveUser` on protected routes. The job is an in-process interval guarded by a Mongo lease, made idempotent by a unique event key.

**Tech Stack:** Node/Express 5, Mongoose 8, multer (memory storage), Node `crypto` (AES-256-GCM), Jest + supertest + mongodb-memory-server. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-22-kyc-verification-design.md` (sections 6.2 to 6.7, 6.10, 6.11). Stage 1 plan for context: `docs/superpowers/plans/2026-11-22-kyc-stage1-app-user-sessions.md`.

## Global Constraints

- No new npm dependencies. Encryption uses Node `crypto` AES-256-GCM.
- Identity: protected KYC routes use `resolveUser` then read `req.userId` (canonical SIP username) and `req.auth`. KYC endpoints require `req.auth.via === 'token'`; legacy requests get `401 { message: 'Sign in required.' }`. `requireKycAccess` on existing protected routes lets legacy requests through unenforced (documented: enforcement requires `LEGACY_USERID_ROUTES=false`).
- Statuses (stored `kyc.status`): `NOT_STARTED`, `IN_PROGRESS`, `PENDING_REVIEW`, `APPROVED`, `REJECTED`, `REQUIRES_CORRECTION`, `EXPIRED`. `RESTRICTED` is never stored as status; it is the computed access state, reported by APIs as `status: 'RESTRICTED'` with `underlyingStatus`, and cached as `kyc.restrictedAt` for reporting.
- Settings defaults (singleton `KycSettings`): `firstNudgeDays 1`, `secondNudgeDays 7`, `reminderIntervalDays 14`, `warningBeforeDays 4`, `enforcementDays 60`, `resubmitGraceDays 14`, `remindersEnabled true`, `rolloutAt` = time the singleton is first created (read-only).
- Restricted = status in {NOT_STARTED, IN_PROGRESS, REJECTED, REQUIRES_CORRECTION, EXPIRED} AND `now >= deadline` AND no exemption with `until > now`.
- Deadline: cycle 0 → `max(appUser.createdAt, settings.rolloutAt) + enforcementDays`; cycle ≥ 1 → `kyc.cycleStartedAt + resubmitGraceDays`.
- Upload rules: JPEG, PNG, PDF only, detected by magic bytes (`FF D8 FF`, `89 50 4E 47 0D 0A 1A 0A`, `25 50 44 46`); max `KYC_MAX_UPLOAD_MB` (default 8) MB; EXIF (JPEG APP1 segments, PNG `eXIf` chunks) removed before encryption; stored under `KYC_STORAGE_DIR` (default `<backend>/kyc_storage`, gitignored, never served statically) with a random 32-byte hex name.
- `KYC_ENCRYPTION_KEY`: base64 of exactly 32 bytes. Missing or wrong length → KYC routes return `503 { message: 'KYC is temporarily unavailable.' }` and the job does not start; the rest of the app keeps working. Tests set a key in `tests/setup-env.js`.
- ID numbers encrypted at rest; APIs return them masked (`•••• ` + last 4). Never log ID numbers, document contents, tokens or passwords. No `console.log` added (the job may report counts via the existing pattern, with no personal data).
- Admin KYC routes: `requireAdmin(['super_admin','kyc_reviewer'])`; `PUT` settings: `requireAdmin(['super_admin'])`. Add `kyc_reviewer` to the staff role enum.
- Every admin action and every system action writes a `KycEvent`.
- User-facing copy: no em dashes; specific; plain.
- Times stored and compared in UTC. All schedule and job functions take `now: Date` as a parameter.

## Review Focus

- Job down for days then restarts: only the latest due reminder is sent; older missed stages are recorded as skipped, not sent in a burst. Test in Task 5.
- Settings changed mid-cycle (e.g. enforcementDays 60 → 30): users past the new deadline become restricted on the next request, not only after the job runs. Test in Task 4.
- A restricted user submits KYC: they regain access immediately (PENDING_REVIEW), before any reviewer acts. Test in Task 4.
- Upload with a `.jpg` name and `image/jpeg` MIME but PDF or HTML bytes: rejected by content, not trusted by header. Test in Task 3.
- Reviewer approves a user who has an open exemption or a pending draft: approval wins, exemption is irrelevant, draft is cleared. Test in Task 6.

---

### Task 1: KYC schedule logic, settings and AppUser KYC fields

**Files:**
- Create: `backend/kyc/models/kyc_settings.model.js`, `backend/kyc/schedule.js`
- Modify: `backend/models/app_user.model.js` (add `kyc` subdocument), `backend/models/user.model.js:17` (add `kyc_reviewer` to role enum)
- Test: `backend/tests/kyc.schedule.test.js`

**Interfaces:**
- Produces:
  - `AppUser.kyc`: `{ status (enum above, default 'NOT_STARTED'), cycle (Number, default 0), cycleStartedAt (Date), startedAt, submittedAt, verifiedAt, reviewedBy (String staff username), rejectionReason, correctionNotes, restrictedAt (Date, cached), lastReminderAt, lastReminderStage (String), exemption: { until: Date, reason: String, grantedBy: String }, lastUpdatedAt }`.
  - `KycSettings.getSettings() => Promise<settingsDoc>` (creates the singleton with defaults and `rolloutAt = now` on first call; static).
  - `computeKycState(appUser, settings, now) => { status, underlyingStatus, restricted, deadline: Date|null, exemptUntil: Date|null, dueStage: string|null, skippedStages: string[] }` where `status` is `'RESTRICTED'` when restricted else `underlyingStatus`; `deadline` null for APPROVED and PENDING_REVIEW.
  - `reminderSchedule(appUser, settings) => Array<{ stage: string, at: Date }>` for the current cycle. Cycle 0 stages: `NUDGE_1` (clockStart + firstNudgeDays), `NUDGE_2` (+ secondNudgeDays), `REMINDER_<k>` at clockStart + k × reminderIntervalDays for k ≥ 1 while before the warning, `WARNING` (deadline − warningBeforeDays), `RESTRICTED` (deadline). Cycle ≥ 1: `REMINDER_<k>` from cycleStartedAt while before the warning, `WARNING`, `RESTRICTED`. Stages that would land after the warning or before the previous stage are dropped.
  - `dueStage` = latest stage with `at <= now` whose name is not `kyc.lastReminderStage` and is later in the schedule than it; `skippedStages` = earlier unsent stages that are also past. Both null/empty when reminders are disabled or status is APPROVED or PENDING_REVIEW.

- [ ] **Step 1: Write failing tests** (pure functions, fixed dates; `createdAt = 2026-01-01T00:00:00Z`, `rolloutAt = 2025-12-01`):
  - `default schedule reproduces days 1, 7, 14, 28, 42, 56, 60` — stage names `NUDGE_1, NUDGE_2, REMINDER_1, REMINDER_2, REMINDER_3, WARNING, RESTRICTED` at those day offsets.
  - `clock starts at rolloutAt for users created before rollout` — `createdAt 2025-06-01`, `rolloutAt 2026-01-01` → deadline `2026-03-02`.
  - `not restricted on day 59, restricted on day 60` (status NOT_STARTED).
  - `PENDING_REVIEW and APPROVED are never restricted and have no due stage`, even on day 200.
  - `IN_PROGRESS, REJECTED, REQUIRES_CORRECTION, EXPIRED are restrictable`.
  - `active exemption suppresses restriction until it expires` — exemption until day 70: day 65 not restricted, day 71 restricted.
  - `correction cycle uses resubmitGraceDays from cycleStartedAt` — cycle 1 started day 80 → deadline day 94; stages `WARNING` at day 90, `RESTRICTED` at day 94 (interval 14 produces no REMINDER before the warning).
  - `changing enforcementDays moves the deadline` — enforcementDays 30 → restricted on day 30.
  - `remindersEnabled false → dueStage null but restriction still applies`.
  - `after a long gap only the latest due stage is due, the rest are skipped` — lastReminderStage `NUDGE_1`, now day 45 → dueStage `REMINDER_3`, skippedStages `['NUDGE_2','REMINDER_1','REMINDER_2']`.
  - `getSettings creates singleton once with defaults` (Mongo memory server).
- [ ] **Step 2:** `cd backend && npx jest --runInBand tests/kyc.schedule.test.js` — FAIL.
- [ ] **Step 3:** Implement. Day arithmetic in UTC milliseconds (`days × 86 400 000`).
- [ ] **Step 4:** Run file + full suite — PASS.
- [ ] **Step 5:** Commit `Add KYC schedule logic, settings and user KYC fields`.

### Task 2: Encryption, file sniffing and private document storage

**Files:**
- Create: `backend/kyc/crypto.js`, `backend/kyc/files.js`, `backend/kyc/storage.js`
- Modify: `backend/tests/setup-env.js` (set `KYC_ENCRYPTION_KEY` to a test-only 32-byte base64 value and `KYC_STORAGE_DIR` to a per-run temp dir), `.gitignore` (add `backend/kyc_storage/`)
- Test: `backend/tests/kyc.files.test.js`

**Interfaces:**
- Produces:
  - `crypto.js`: `kycKeyAvailable() => boolean`; `encryptBuffer(buf) => Buffer` (layout: 12-byte IV ‖ 16-byte tag ‖ ciphertext); `decryptBuffer(buf) => Buffer` (throws on tamper); `encryptField(str) => string` (base64 of the same layout); `decryptField(str) => string`; `maskId(str) => string` (`'•••• ' + last 4`, or `'••••'` if shorter than 4).
  - `files.js`: `sniffType(buf) => 'image/jpeg' | 'image/png' | 'application/pdf' | null`; `stripMetadata(buf, type) => Buffer` (JPEG: drop APP1 segments `FF E1`; PNG: drop `eXIf` chunks; PDF unchanged).
  - `storage.js`: `saveEncrypted(buf) => Promise<{ storageKey: string, size: number, sha256: string }>` (sha256 of plaintext after stripping); `readDecrypted(storageKey) => Promise<Buffer>`; `deleteStored(storageKey) => Promise<void>`. `storageKey` must match `/^[0-9a-f]{64}$/`, otherwise throw (no path traversal).

- [ ] **Step 1: Write failing tests:**
  - `encrypt/decrypt round trip` and `decrypt throws when one byte is flipped`.
  - `two encryptions of the same input differ` (random IV).
  - `kycKeyAvailable false for missing or 31-byte key`.
  - `maskId('63-1234567-A-89') === '•••• A-89'` and short input.
  - `sniffType` on `tests/fixtures/tiny.png` → png; on a JPEG header buffer → jpeg; `%PDF-1.4` → pdf; `<html>` → null; empty → null.
  - `stripMetadata removes JPEG APP1 and keeps other segments` (build a minimal JPEG: SOI, APP0, APP1 with `Exif\0\0` + GPS bytes, DQT, EOI → output has no `Exif` string, still starts with `FF D8` and ends with `FF D9`).
  - `stripMetadata removes PNG eXIf chunk` (insert an `eXIf` chunk into tiny.png → removed, IHDR/IDAT/IEND intact).
  - `saveEncrypted writes ciphertext only` — file on disk does not contain the plaintext bytes; `readDecrypted` returns the original.
  - `readDecrypted rejects '../x' and non-hex keys`.
- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3:** Implement. Key read at call time from env.
- [ ] **Step 4:** Run file + full suite — PASS.
- [ ] **Step 5:** Commit `Add KYC encryption and private document storage`.

### Task 3: User KYC API (status, draft, documents, submit)

**Files:**
- Create: `backend/kyc/models/kyc_draft.model.js`, `kyc_document.model.js`, `kyc_submission.model.js`, `kyc_event.model.js`; `backend/kyc/validation.js`; `backend/kyc/routes/kyc_user.routes.js`
- Modify: `backend/index.js` (mount at `/api/kyc`), `backend/middleware/rate_limits.js` (add `kycUploadLimiter`)
- Test: `backend/tests/kyc.user_api.test.js`

**Interfaces:**
- Consumes: `resolveUser`, `computeKycState`, `getSettings`, Task 2 modules.
- Produces models:
  - `KycDraft { appUserId (unique), data: Object, updatedAt }`.
  - `KycDocument { appUserId, kind: 'id_front'|'id_back'|'passport_bio'|'proof_of_residence', storageKey, mime, size, sha256, submissionId (null while in draft), createdAt }`.
  - `KycSubmission { appUserId, version (1-based per user), personal: {firstName,lastName,dateOfBirth,gender,nationality}, address: {line1,line2,city,country}, identification: {idType:'national_id'|'passport', idNumberEnc, idExpiry}, phone, documentIds: [ObjectId], submittedAt, decision: 'pending'|'approved'|'rejected'|'correction_requested'|'expired', decidedBy, decidedAt, reason }`.
  - `KycEvent { appUserId, actor ('system' | 'user' | staff username), type, data: Object, idempotencyKey (unique, sparse), createdAt }`. Types used in 2a: `DRAFT_SAVED` (first save only), `DOCUMENT_UPLOADED`, `SUBMITTED`, `REMINDER_SENT`, `REMINDER_SKIPPED`, `RESTRICTED`, `UNRESTRICTED`, `APPROVED`, `REJECTED`, `CORRECTION_REQUESTED`, `EXPIRED`, `EXEMPTION_GRANTED`, `SETTINGS_CHANGED`, `DOCUMENT_VIEWED`, `ID_REVEALED`, `MANUAL_REMINDER`.
- `validation.js`: `validateDraft(data) => { ok, errors }` (types and lengths only, all optional); `validateSubmission(data, docs) => { ok, errors: { [field]: message } }`. Required: firstName, lastName (1–60 chars), dateOfBirth (ISO date, age 16 to 120), gender (`male|female|other`), nationality (2–56 chars), address.line1 (1–120), address.city (1–60), address.country (2–56), idType; national_id number matches `/^\d{2}-?\d{6,7}-?[A-Z]-?\d{2}$/i`; passport number `/^[A-Z0-9]{6,12}$/i` plus `idExpiry` in the future; documents: national_id needs `id_front` and `id_back`, passport needs `passport_bio`; `proof_of_residence` required only if env `KYC_REQUIRE_PROOF_OF_RESIDENCE === 'true'`.
- Routes (all: `resolveUser({ field: 'userId' })`, then 401 unless `req.auth?.via === 'token'`, then 503 unless `kycKeyAvailable()`):
  - `GET /api/kyc/me` → `{ status, underlyingStatus, deadline, exemptUntil, progress (0–100: 5 steps personal/address/identification/documents/review, 20 each), outstanding: string[] (field/document keys still missing), draft (with idNumber masked), documents: [{id, kind, mime, size, createdAt}], history: [{version, submittedAt, decision, decidedAt, reason}], rejectionReason, correctionNotes, phone }`. `phone` = `req.userId`, read-only.
  - `PUT /api/kyc/draft` body `{ data }` → upsert draft; if status NOT_STARTED set IN_PROGRESS and `startedAt`; 400 on `validateDraft` errors; 409 `{ message: 'Your KYC is already submitted.' }` if status PENDING_REVIEW or APPROVED. ID number stored encrypted inside draft data.
  - `POST /api/kyc/documents` multipart `file` + `kind` → memory multer limited to `KYC_MAX_UPLOAD_MB`; sniff, 415 `{ message: 'Upload a JPEG, PNG or PDF file.' }` on mismatch; strip, save; replaces an existing draft document of the same kind (old file deleted); 201 `{id, kind, mime, size, createdAt}`; 413 on size. Rate limit `kycUploadLimiter` 30 / hour keyed by `req.userId`.
  - `DELETE /api/kyc/documents/:id` → own draft documents only (404 otherwise, including other users' ids).
  - `GET /api/kyc/documents/:id` → own documents only; streams decrypted bytes with stored `Content-Type`, `Cache-Control: no-store`, `Content-Disposition: inline`.
  - `POST /api/kyc/submit` → `validateSubmission`; 400 `{ message: 'Some details are missing or invalid.', errors }`; creates submission (version n+1) linking draft documents; status PENDING_REVIEW, `submittedAt`, clear `restrictedAt`; event `SUBMITTED` (+ `UNRESTRICTED` if previously restricted); deletes the draft; 201 `{ status: 'PENDING_REVIEW', submittedAt }`. 409 if already PENDING_REVIEW or APPROVED.

- [ ] **Step 1: Write failing tests** (sign app tokens with `signAppToken`; create AppUser rows directly):
  - `GET /me for a new user returns NOT_STARTED, progress 0, a deadline 60 days after clock start`.
  - `legacy request (no token, LEGACY on) to /api/kyc/me is 401`.
  - `saving a draft moves NOT_STARTED to IN_PROGRESS and resumes on GET /me` with idNumber masked in the response.
  - `upload accepts a real PNG, returns metadata, and the stored file is encrypted`.
  - `upload rejects HTML bytes sent as image/jpeg with 415`, and `rejects oversize with 413` (set `KYC_MAX_UPLOAD_MB=0.001` for that test).
  - `user B cannot GET or DELETE user A's document` (404).
  - `submit with missing fields returns 400 with field errors`.
  - `submit with complete data creates PENDING_REVIEW, version 1, links documents, deletes draft`.
  - `submit twice returns 409`.
  - `national id requires front and back; passport requires bio page and future expiry`.
  - `GET /me never returns the raw ID number` (search the JSON for the full number).
  - `503 when KYC_ENCRYPTION_KEY is missing` (unset in one test, restore after).
- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run file + full suite — PASS.
- [ ] **Step 5:** Commit `Add user KYC API with drafts, encrypted uploads and submission`.

### Task 4: Server-side restriction of protected routes

**Files:**
- Create: `backend/kyc/require_kyc_access.middleware.js`
- Modify: `backend/index.js` (add after `resolveUser` on: cart ×5, orders POST+GET, wishlist ×3, shipping-addresses ×3, superapp-pay, posts POST/like/DELETE; NOT on `GET /api/products`)
- Test: `backend/tests/kyc.enforcement.test.js`

**Interfaces:**
- Consumes: `computeKycState`, `getSettings`, `AppUser`.
- Produces: `requireKycAccess` middleware. `req.auth?.via !== 'token'` → `next()` (legacy unenforced). Otherwise load AppUser by `req.auth.appUserId` (404-safe: missing user → 401 `Sign in required.`), compute state live; restricted → `403 { code: 'KYC_RESTRICTED', message: 'Complete your KYC verification to keep using this feature.', status: 'RESTRICTED', underlyingStatus, deadline }`, and if `kyc.restrictedAt` is unset, set it and write `RESTRICTED` event (idempotency key `${appUserId}:restricted:${cycle}`). Not restricted but `restrictedAt` set → clear it and write `UNRESTRICTED`. Multipart upload on `POST /api/posts` is deleted on 403 (same as the 401 path).
- Settings are read once per request (no cache) so admin changes apply immediately.

- [ ] **Step 1: Write failing tests** (control time by setting `createdAt` in the past and `rolloutAt` in settings; no fake timers needed):
  - `user on day 10 can use the cart`.
  - `user past the deadline gets 403 KYC_RESTRICTED on cart, orders, wishlist, shipping addresses, payments, posts` (table over one request per route).
  - `restricted user can still GET /api/kyc/me, save a draft, upload, submit, read notifications, browse products and FAQs, and refresh their session`.
  - `restricted user who submits regains cart access immediately`.
  - `approved user past the deadline is not restricted`.
  - `lowering enforcementDays restricts on the next request` (update settings, no job run).
  - `legacy request (no token) is not enforced`.
  - `RESTRICTED event written once even after several blocked requests`.
  - `post upload rejected with 403 leaves no file in uploads/`.
- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3:** Implement and wire.
- [ ] **Step 4:** Run file + full suite — PASS (existing route tests use fresh users, inside the grace period).
- [ ] **Step 5:** Commit `Restrict protected routes when the KYC deadline passes`.

### Task 5: In-app notifications and the reminder job

**Files:**
- Create: `backend/kyc/models/notification.model.js`, `backend/kyc/models/job_lock.model.js`, `backend/kyc/notifications.js`, `backend/kyc/job.js`, `backend/kyc/routes/notifications.routes.js`
- Modify: `backend/index.js` (mount `/api/notifications`; start the job inside `if (require.main === module)` when `KYC_JOB_ENABLED !== 'false'` and `kycKeyAvailable()`)
- Test: `backend/tests/kyc.job.test.js`, `backend/tests/notifications.test.js`

**Interfaces:**
- Produces:
  - `Notification { appUserId, kind, title, body, createdAt, readAt, deliveredVia: ['in_app'] }`.
  - `notify(appUserId, kind, vars) => Promise<Notification>` using the template table below; a channel list `[inApp]` with the shape `{ name, send(notification) }` so push/email can be added later (only `inApp` registered).
  - `runKycJob({ now, batchSize = 500 }) => Promise<{ reminded, skipped, restricted }>`: if reminders disabled, only restriction caching runs. Scans AppUsers whose status is restrictable (cursor, batched). For each: compute state; for each `skippedStages` insert `REMINDER_SKIPPED` events; for `dueStage` insert `REMINDER_SENT` with idempotencyKey `${appUserId}:${cycle}:${stage}` — on duplicate-key error skip (already sent); otherwise `notify` and set `lastReminderAt`, `lastReminderStage`. If restricted and `restrictedAt` unset → set it, event `RESTRICTED` (same key as Task 4).
  - `startKycJob({ intervalMs }) => stop()`: every `KYC_JOB_INTERVAL_MS` (default 900 000) acquires a lease (`JobLock { name: 'kyc', holder, expiresAt }`, atomic `findOneAndUpdate` where `expiresAt < now`, lease = 2 × interval) and calls `runKycJob({ now: new Date() })`. Errors are caught per run; failed users are retried on the next run because their event was not written.
  - Notification API (`resolveUser` + token required; NOT behind `requireKycAccess`): `GET /api/notifications?page=` → `{ items: [{id, kind, title, body, createdAt, readAt}], unread, page, totalPages }` (20 per page, newest first); `POST /api/notifications/:id/read` → own only, 404 otherwise.
- Templates (`kind`: title / body). `{deadline}` formatted `22 January 2027` in UTC:
  - `NUDGE_1`: "Verify your number" / "POTRAZ rules require us to confirm who owns each number. It takes about 5 minutes. Complete it before {deadline}."
  - `NUDGE_2`: "Your KYC is still open" / "Finish your KYC before {deadline} to keep calling, shopping and paying without interruption."
  - `REMINDER`: "Reminder: complete your KYC" / "Your KYC verification is still outstanding. Complete it before {deadline}."
  - `WARNING`: "Your account will be limited soon" / "Complete your KYC before {deadline}. After that, calls, shopping, payments and posts will be paused until you verify."
  - `RESTRICTED`: "Your account is limited" / "We have paused calls, shopping, payments and posts because your KYC is not complete. Emergency calls still work. Complete KYC to restore access."
  - `SUBMITTED`: "KYC received" / "We are reviewing your details. You can keep using the app while we check them."
  - `APPROVED`: "You are verified" / "Your KYC has been approved. Thank you."
  - `REJECTED`: "KYC not approved" / "Reason: {reason}. Please correct your details and submit again before {deadline}."
  - `CORRECTION_REQUESTED`: "KYC needs a correction" / "{reason}. Please update your details and submit again before {deadline}."
  - `EXPIRED`: "Please renew your KYC" / "Your verified details have expired. Submit updated details before {deadline}."
  `REMINDER_<k>` stages use the `REMINDER` template. Task 3's submit also calls `notify(..., 'SUBMITTED')` (add in this task).

- [ ] **Step 1: Write failing tests** (`runKycJob` called directly with explicit `now`):
  - `user receives NUDGE_1 on day 1, NUDGE_2 on day 7, reminders on 14, 28, 42, WARNING on 56` — call the job on each of those days; one notification per call with the right kind.
  - `running the job twice on the same day sends nothing new` (no duplicates).
  - `job on day 5 sends nothing` (between stages, NUDGE_1 already sent).
  - `job restarted on day 45 after a gap sends only REMINDER_3 and records skips`.
  - `approved and pending users get no reminders`.
  - `user who submits stops receiving reminders`.
  - `restriction is cached with a RESTRICTED notification on day 60, once`.
  - `REQUIRES_CORRECTION cycle sends WARNING and RESTRICTED against the new deadline`.
  - `remindersEnabled false sends nothing but still caches restriction`.
  - `two concurrent runKycJob calls on the same day still send one notification` (Promise.all).
  - `lease: second acquire fails while the first is held, succeeds after expiry`.
  - Notifications API: list paginated newest first with unread count; mark read; user B cannot mark A's; restricted user can read notifications.
- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run files + full suite — PASS.
- [ ] **Step 5:** Commit `Add KYC reminder job and in-app notifications`.

### Task 6: Admin KYC API

**Files:**
- Create: `backend/kyc/routes/kyc_admin.routes.js`
- Modify: `backend/index.js` (mount at `/api/admin/kyc`)
- Test: `backend/tests/kyc.admin_api.test.js`

**Interfaces:**
- Consumes: everything above; `requireAdmin`.
- Produces (all `requireAdmin(['super_admin','kyc_reviewer'])` unless stated; staff username from `req.user.username` is the actor):
  - `GET /stats` → `{ total, approved, notStarted, inProgress, pendingReview, rejected, requiresCorrection, expired, restricted }` (`restricted` computed against current settings).
  - `GET /users?q=&status=&page=&limit=` → paginated `{ items: [{ id, username, displayName, registeredAt, status, underlyingStatus, submittedAt, lastReminderAt, deadline }], page, totalPages, total }`; `q` matches username or displayName (escaped regex, case-insensitive); `status` accepts any status or `RESTRICTED`; `limit` max 100, default 25.
  - `GET /users/:id` → user row + full submission history (ID number masked; `?reveal=1` returns it decrypted and writes event `ID_REVEALED`), documents per submission, last 100 events.
  - `GET /documents/:id` → decrypted stream; writes `DOCUMENT_VIEWED` (actor, document id, kind; no content).
  - `POST /users/:id/approve` → requires PENDING_REVIEW (409 otherwise); status APPROVED, `verifiedAt`, `reviewedBy`, clear exemption, `restrictedAt`, `rejectionReason`, `correctionNotes`; latest submission decision approved; event; notify APPROVED.
  - `POST /users/:id/reject` `{ reason }` (5–500 chars, 400 otherwise) → requires PENDING_REVIEW; status REJECTED, `rejectionReason`, `cycle += 1`, `cycleStartedAt = now`; submission decision rejected; event; notify REJECTED with the new deadline.
  - `POST /users/:id/request-correction` `{ reason }` → same as reject but status REQUIRES_CORRECTION, `correctionNotes`.
  - `POST /users/:id/expire` `{ reason }` → requires APPROVED; status EXPIRED, new cycle; event; notify EXPIRED.
  - `POST /users/:id/exemption` `{ until (ISO, future, ≤ 90 days ahead), reason (5–500) }` → sets exemption; event `EXEMPTION_GRANTED`.
  - `POST /users/:id/remind` → sends a `REMINDER` notification now if status is restrictable (409 otherwise); event `MANUAL_REMINDER`; rate limited to once per user per hour (409 `{ message: 'A reminder was sent in the last hour.' }`).
  - `GET /settings` (any KYC admin) / `PUT /settings` (`super_admin` only) with integer validation: all day values 1–365, `secondNudgeDays > firstNudgeDays`, `warningBeforeDays < enforcementDays`; event `SETTINGS_CHANGED` with before/after.
  - `GET /audit?appUserId=&type=&page=` → events, newest first, 50 per page.

- [ ] **Step 1: Write failing tests:**
  - `kyc_reviewer and super_admin can list; staff and app tokens cannot` (403 / 401).
  - `stats count each status and restricted users`.
  - `search by partial username and filter by RESTRICTED`.
  - `approve restores access to a restricted user who had submitted` (cart 403 before submit, 200 after approve).
  - `approve requires PENDING_REVIEW` (409).
  - `reject requires a reason, starts a new cycle, user can edit draft and resubmit as version 2`.
  - `request-correction gives a 14-day grace from now and notifies the user with the reason`.
  - `exemption lifts restriction until it expires and is audited`; `exemption over 90 days is 400`.
  - `approving clears an existing exemption and leftover draft`.
  - `document view is audited and the response is the original bytes`.
  - `ID number masked unless reveal=1, which is audited`.
  - `PUT settings by kyc_reviewer is 403; invalid values 400; valid change audited and applied to the next request`.
  - `manual remind once per hour`.
- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run file + full suite — PASS.
- [ ] **Step 5:** Commit `Add admin KYC review API`.

### Task 7: Configuration, retention script and live check

**Files:**
- Create: `backend/docs/kyc.md`, `backend/scripts/kyc-purge-user.js`
- Modify: `backend/.env.example` (add `KYC_ENCRYPTION_KEY`, `KYC_STORAGE_DIR`, `KYC_MAX_UPLOAD_MB`, `KYC_REQUIRE_PROOF_OF_RESIDENCE`, `KYC_JOB_ENABLED`, `KYC_JOB_INTERVAL_MS`, with one-line comments)
- Test: `backend/tests/kyc.purge.test.js`

**Interfaces:**
- `kyc-purge-user.js <sipUsername> [--apply]`: dry run by default (prints counts only); `--apply` deletes that user's KycDraft, KycDocument rows and stored files, KycSubmission rows, notifications; keeps KycEvent rows with personal data removed from `data` (audit trail kept). Not scheduled.
- `kyc.md`: generating the key (`node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`), storing it only in the host's secret settings, key loss = documents unrecoverable; storage directory must be on a persistent disk (Render's filesystem is ephemeral without one, so `[OWNER TO DECIDE: persistent disk or object storage]`); reminder/deadline settings and where to change them (admin API now, admin page in Stage 3); how the job runs and how to disable it; enforcement requires `LEGACY_USERID_ROUTES=false`; full lifecycle test walkthrough with curl (create user → day offsets via settings → submit → approve); retention `[CONFIRM WITH COMPLIANCE]`.

- [ ] **Step 1: Write failing purge tests:** dry run changes nothing; apply removes documents and files but keeps scrubbed events.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** PASS + full suite.
- [ ] **Step 5:** Live check: start the backend locally with an in-memory Mongo (throwaway script in the scratchpad, not committed) and show real responses: `GET /api/kyc/me` (200), upload a PNG (201), submit incomplete (400), cart for a user created 61 days ago (403 KYC_RESTRICTED), approve via admin API, cart again (200).
- [ ] **Step 6:** Commit `Document KYC configuration and add retention script`.

---

Stage 2b (Flutter: KYC form, status page, reminder sheet, mandatory screen, call lock) gets its own plan after this lands, built against the API above.
