# KYC Verification (POTRAZ subscriber registration) — Design

Date: 2026-11-22
Status: Draft, awaiting approval

## 1. Intent and why

The app hands out phone numbers (via Afri Com SIP accounts). Zimbabwe's subscriber
registration rules (POTRAZ; understood to be the Postal and Telecommunications
(Subscriber Registration) Regulations, SI 95 of 2014 — `[CONFIRM WITH COMPLIANCE]`)
require every subscriber to be identified. We need every app user to submit KYC, get
reminded on a schedule, be restricted if they ignore it past a deadline, and have
staff verify submissions in the existing admin panel.

Success: every active user is either Verified, Pending review, or inside their grace
period; users who ignore KYC past the deadline cannot place normal calls or use
shopping/payments/posts until they submit.

## 2. Goals, non-goals, anti-goals

Goals
- Central KYC status per app user, stored in MongoDB via the existing Node backend.
- Multi-step KYC form in the Flutter app with autosave/resume and document upload.
- Timestamp-driven reminders and deadline enforcement by a backend job.
- Server-side enforcement on backend routes, plus app-side lock on outgoing calls.
- KYC page in the existing admin panel: stats, table, review, settings, exemptions, audit log.
- Everything configurable from the admin panel; no hardcoded intervals.

Non-goals (this project)
- Push notifications and email delivery (no infrastructure today). A delivery-channel
  interface is built so they can be added later.
- Automated ID/selfie verification vendor. The review step is designed so one can be added.
- Network-level SIP suspension via Afri Com (Option B). A hook point is left in the
  restriction service.
- Forwarding records to Afri Com's subscriber register. `[CONFIRM WITH AFRI COM]` whether required.

Anti-goals (failure even if it "works")
- Locking a user out of emergency calls or incoming calls.
- Locking existing users out on launch day.
- KYC documents reachable through any public URL, or ID numbers in logs.
- Restriction enforced only in the UI.
- Submitting automatically marking anyone Verified.

## 3. Constraints found in the codebase

- App users authenticate only with Afri Com (gRPC, OTP verified server-side by Afri Com,
  which returns a SIP username + password). The Node backend has no notion of app users;
  routes such as cart, orders, posts trust a `userId` from the request.
- Backend `User` model = admin staff only (`super_admin`, `shop_manager`, `staff`).
- `POST /api/auth/register` is public and creates `staff` accounts. Any staff JWT passes
  `auth.middleware.js`, which accepts any valid JWT.
- `/uploads` is served publicly via `express.static`.
- No scheduler, no push, no email.
- Calls go phone → Afri Com SIP directly; the backend never sees them.
- Stack: Express 5, Mongoose 8, multer, helmet, express-rate-limit, Jest + supertest +
  mongodb-memory-server. Admin panel: plain HTML/JS with JWT in localStorage. App: Flutter,
  Provider/get_it, MVVM under `lib/features/*`.

## 4. Approaches

- **A. All in-house, manual review (chosen).** KYC model, encrypted private document
  storage, reminder job, enforcement middleware in the existing backend; form in Flutter;
  review page in the existing admin panel. No new vendor, data stays on our servers
  (relevant to the Cyber and Data Protection Act's cross-border limits). Cost: staff review load.
- B. In-house plus ID-verification vendor (e.g. Smile ID). Less manual review, better fraud
  catching; per-check cost, contract, cross-border transfer needs legal review. Deferred;
  review step designed to accept it later.
- Separate KYC service: rejected (spec forbids a disconnected system).

Calling restriction: **Option A chosen** — app refuses outgoing calls while restricted
(emergency numbers and incoming calls always allowed); backend blocks shopping, payments,
posts. Known weakness: a modified app could bypass the call lock. Option B (Afri Com
suspends SIP account) left as a hook.

## 5. Decisions made with the owner

1. Driver is POTRAZ subscriber registration.
2. Call lock is app-side (Option A).
3. Existing users: everyone's clock starts on rollout day (full grace period from launch).
4. Approach A (in-house, manual review).
5. On submit, status becomes PENDING_REVIEW and the user keeps **full access**; the deadline
   stops counting. Staff later mark them APPROVED (shown to users as "Verified").

## 6. Design

### 6.1 Prerequisite: backend sessions for app users

- New `AppUser` model (separate from staff `User`): `sipUsername` (unique, the Afri Com
  username / phone number), `displayName`, `phone`, `createdAt`, plus KYC fields (6.2).
- `POST /api/app-auth/session` `{ username, password }` → backend calls Afri Com
  `AccountBalance` server-to-server with those credentials; on success upserts `AppUser`
  and returns a JWT with `aud: "app"`, `sub: appUserId`, 7-day expiry, plus a refresh path
  that re-verifies with Afri Com. Rate limited (existing `authLimiter`).
  Needs two new backend dependencies, `@grpc/grpc-js` and `@grpc/proto-loader` (the
  official Node gRPC packages; owner approval required before install).
  `[VERIFY]` Afri Com permits gRPC calls from our backend host; if not, this blocks
  server-side enforcement and we stop and reconsider.
- Staff JWTs get `aud: "admin"`. `auth.middleware.js` split into `requireAdmin(roles?)`
  and `requireAppUser`, each checking `aud`. Existing admin routes switch to `requireAdmin`.
- Lock down `POST /api/auth/register`: only a `super_admin` can create staff accounts.
- Migrate user-scoped routes (cart, orders, wishlist, shipping addresses, posts create/
  like/delete, superapp-pay) to `requireAppUser` and take identity from the token, not
  from `userId` in the request. Flutter services updated to send the bearer token.
  Rollout: accept both for one release behind `LEGACY_USERID_ROUTES=true`, then remove.
- New staff role `kyc_reviewer`; `super_admin` can also review.

### 6.2 Data model

`AppUser.kyc` (embedded; one record per user, no duplicate users):
`status` (NOT_STARTED | IN_PROGRESS | PENDING_REVIEW | APPROVED | REJECTED |
REQUIRES_CORRECTION | EXPIRED | RESTRICTED), `startedAt`, `submittedAt`, `verifiedAt`,
`reviewedBy`, `rejectionReason`, `correctionNotes`, `restrictionReason`, `deadline`,
`lastReminderAt`, `nextReminderAt`, `reminderStage`, `lastUpdatedAt`,
`exemption { until, reason, grantedBy }`.

Note: RESTRICTED is a derived *access* state but stored for querying/reporting; the
underlying progress (NOT_STARTED / IN_PROGRESS / REJECTED / REQUIRES_CORRECTION) is kept
in `kyc.progressStatus` so lifting a restriction returns the right status.

`KycSubmission` (one per submit; history): `appUserId`, `version`, personal fields,
identification fields (ID number encrypted), document refs, `submittedAt`, `decision`,
`decidedBy`, `decidedAt`, `reason`. Draft lives in `KycDraft` (one per user, autosaved).

`KycDocument`: `appUserId`, `submissionId|draftId`, `kind` (id_front, id_back,
passport_bio, proof_of_residence), `storageKey` (random 32-byte hex), `mime`, `size`,
`sha256`, `createdAt`. File bytes encrypted.

`KycSettings` (singleton): `reminderIntervalDays` (14), `firstNudgeDays` (1), `secondNudgeDays` (7),
`enforcementDays` (60), `warningBeforeDays` (4 → day-56 warning), `resubmitGraceDays`
(14), `remindersEnabled` (true), `rolloutAt` (set at launch).

`KycEvent` (audit + notifications log): `appUserId?`, `actor` (system | staff id | user),
`type` (REMINDER_SENT, RESTRICTED, UNRESTRICTED, SUBMITTED, APPROVED, REJECTED,
CORRECTION_REQUESTED, EXEMPTION_GRANTED, SETTINGS_CHANGED, DOCUMENT_VIEWED, ...),
`data`, `createdAt`, `idempotencyKey` (unique, sparse).

`Notification` (in-app inbox): `appUserId`, `kind`, `title`, `body`, `createdAt`,
`readAt`, `deliveredVia[]`. Delivery channel interface: `inApp` implemented; `push`,
`sms`, `email` stubs not registered.

Clock start: `AppUser` records are created on a user's first backend session, which
happens on first app open after this release (existing users) or at registration (new
users). `kyc.clockStartedAt = max(createdAt, settings.rolloutAt)`. This satisfies the
"everyone starts on rollout day" decision without needing a list of existing users
(Afri Com holds that list, not us). Users who never open the app again are never
reminded, which is acceptable: they are not using the service.

### 6.3 Timeline and rules

Clock start `T0 = max(registration, rolloutAt)`. Deadline `T0 + enforcementDays`.
Reminder stages are computed from settings, never hardcoded:
`firstNudgeDays` (1), `secondNudgeDays` (7), then every `reminderIntervalDays` (14) from
day 14 while before the warning, a warning at `deadline - warningBeforeDays` (day 56),
restriction at `deadline` (day 60). Defaults reproduce the spec table exactly
(1, 7, 14, 28, 42, 56, 60). Interval and deadline are independent settings. Stage
schedule is recomputed from `T0` and current settings each run, so changing settings
applies to everyone without rewriting rows.

Rules
- APPROVED: no reminders, never restricted (until EXPIRED, which is out of scope for
  scheduling; status exists, set manually by staff for now).
- PENDING_REVIEW: full access, no reminders, deadline paused.
- REJECTED / REQUIRES_CORRECTION: correction notification; new deadline
  `now + resubmitGraceDays`; reminders resume against that deadline.
- Active exemption: not restricted until `exemption.until`; then normal rules.
- Approval lifts restriction immediately.
- Profile edits never touch `KycSubmission` data; verified data is read-only to the user.

### 6.4 Background job

In-process `setInterval` (every 15 min, configurable `KYC_JOB_INTERVAL_MS`) in the
backend, no new dependency. Guarded by a Mongo lease document (`jobLocks`) so only one
instance runs at a time. Each run:
1. Query users whose `nextReminderAt <= now` or `deadline <= now` and status in the
   reminder/enforce set.
2. Insert `KycEvent` with idempotencyKey `${userId}:${stage}:${deadline}`; duplicate key =
   already sent, skip. Then write Notification and advance `nextReminderAt`.
3. Restrict when deadline passed and no active exemption.
All times UTC. Job takes an injectable `now()` for tests. Failed channel deliveries are
recorded and retried on next run (in-app cannot fail independently of the DB write).

### 6.5 Enforcement

- `requireKycAccess` middleware after `requireAppUser`: computes access live from the
  DB (not just the stored status, so a restriction applies even if the job hasn't run yet).
  Restricted → `403 { code: "KYC_RESTRICTED", kycStatus, deadline }`.
- Applied to: cart, orders, wishlist, shipping addresses, superapp-pay, posts create/like/
  delete. Not applied to: app-auth, `/api/kyc/*`, `/api/notifications`, FAQs, help, public
  product/category/shop/banner reads, terms/privacy.
- App: a `KycGate` wraps the authenticated shell. If restricted, it shows the mandatory
  KYC screen (not dismissible; back button handled). The call service refuses outgoing
  calls while restricted except emergency numbers (list `[CONFIRM]`: 999, 993, 994, 995,
  112) — incoming calls untouched. Any API 403 KYC_RESTRICTED flips the gate.

### 6.6 KYC API (all `requireAppUser`)

- `GET /api/kyc/me` — status, deadline, progress %, outstanding items, history (no raw ID numbers; masked).
- `PUT /api/kyc/draft` — autosave partial form. Validated with plain schema functions in
  `kyc/validation.js` (no new dependency); drafts accept partial data, submit requires all.
- `POST /api/kyc/documents` — multipart, one file; allowlist JPEG/PNG/PDF, magic-byte
  check, 8 MB cap (`KYC_MAX_UPLOAD_MB`), EXIF stripped for images `[builder: no new dep —
  re-encode not available; strip APP1 segment manually]`, encrypted AES-256-GCM with
  `KYC_ENCRYPTION_KEY`, stored under `KYC_STORAGE_DIR` (outside `uploads/`, not served).
- `DELETE /api/kyc/documents/:id` — own draft docs only.
- `GET /api/kyc/documents/:id` — own docs only, streamed decrypted.
- `POST /api/kyc/submit` — validates required fields and docs, creates submission,
  status → PENDING_REVIEW, event + admin-visible queue.
- `GET /api/notifications`, `POST /api/notifications/:id/read`.

Admin (`requireAdmin(['super_admin','kyc_reviewer'])`):
- `GET /api/admin/kyc/stats`, `GET /api/admin/kyc/users?q&status&page`,
  `GET /api/admin/kyc/users/:id` (history, events),
  `GET /api/admin/kyc/documents/:id` (streams, logs DOCUMENT_VIEWED),
  `POST /api/admin/kyc/users/:id/approve|reject|request-correction` (reason required for
  the last two), `POST .../exemption {until, reason}`, `POST .../remind`,
  `GET|PUT /api/admin/kyc/settings` (super_admin only for PUT),
  `GET /api/admin/kyc/audit`.

### 6.7 Form fields (POTRAZ set, `[CONFIRM WITH COMPLIANCE]`)

Step 1 Personal: first name, last name, date of birth (18+? `[CONFIRM]`), gender,
nationality. Step 2 Address: residential address, city, country of residence.
Step 3 Identification: ID type (Zimbabwe national ID | passport), number (national ID
format check `NN-NNNNNNN-A-NN`), expiry (passport). Step 4 Documents: national ID front
(+ back if card), or passport bio page; proof of residence `[CONFIRM if required]`.
Step 5 Review & submit. Phone prefilled from account, read-only.

### 6.8 App UI (follow existing theme in `lib/core/theme.dart`)

- Reminder sheet: shown at most once per reminder stage; dismissal remembered per stage.
- KYC status page (from profile and from banner): status, % complete, outstanding items,
  history, reviewer notes.
- Mandatory screen: "Complete your KYC verification", why, outstanding items, progress,
  ~5 min estimate, support link (existing help_support feature), Complete KYC button.
- Restricted banner/lock on dialer explaining calls are paused, emergency calls allowed.

### 6.9 Admin panel

New `kyc.html` + `kyc.js` matching existing pages: stats row (one primary: pending
review), table with search/filter/pagination and status badges, review drawer with
document viewer (fetched with auth, blob URL, never a public link), approve/reject/request
correction with reason, exemption dialog, settings form, audit log tab, manual remind.

### 6.10 Security

AES-256-GCM for document bytes and ID numbers (key from env; `.env.example` lists names
only). No public paths. Ownership checks on every user route. Admin doc access audited.
ID numbers masked in API responses and never logged. Rate limits on session, upload,
submit. Retention: `[CONFIRM WITH COMPLIANCE]` period; deletion script for closed accounts
provided but not scheduled.

### 6.11 Testing (Jest + mongodb-memory-server, injected clock)

Covers spec §13 items 1–14, plus: app token rejected on admin routes, staff register
locked, magic-byte rejection, doc never served without auth, idempotent job reruns,
emergency-number allowlist (Flutter unit test), KycGate behaviour (widget test).

## 7. Stages

1. Sessions & route hardening (6.1).
2. KYC core: model, API, uploads, job, enforcement, Flutter form/gate/call lock.
3. Admin KYC page and settings.

## 8. Left to the builder

File layout inside `backend/` (suggest `kyc/` folder with routes, service, job, crypto),
exact widget structure, copy wording within the design rules, index choices.
