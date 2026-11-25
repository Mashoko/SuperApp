# KYC (subscriber registration)

POTRAZ requires us to know who owns each registered number. Every app user must submit their personal details, an ID number and photos of their ID (or passport), and have them approved by a reviewer. Users get reminders in the app. Once the deadline passes without a verified or pending submission, protected routes (cart, shop, payments, posts) return `403 KYC_RESTRICTED`. This document covers setup, operation and retention for the backend. The app screens are in Stage 2b. Reviewers work in the admin panel's KYC page (see "Admin page").

KYC never blocks calls on the server. The app-side call lock is Stage 2b, and emergency calls are never blocked.

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `KYC_ENCRYPTION_KEY` | none | Base64 of exactly 32 bytes. Encrypts documents and ID numbers. If missing or the wrong length, `/api/kyc/*`, the admin document routes and the launch endpoint return 503, the reminder job does not start, nobody is restricted, and the rest of the app works normally. |
| `KYC_STORAGE_DIR` | `<backend>/kyc_storage` | Where encrypted files are stored. Created with mode 0700, files 0600. Never served over HTTP. |
| `KYC_MAX_UPLOAD_MB` | `8` | Largest accepted upload, in megabytes. |
| `KYC_REQUIRE_PROOF_OF_RESIDENCE` | not required | Set to exactly `true` to require a `proof_of_residence` document on submission. |
| `KYC_JOB_ENABLED` | enabled | Set to exactly `false` to stop this instance running the reminder job. |
| `KYC_JOB_INTERVAL_MS` | `900000` | Milliseconds between job runs (15 minutes). |

### Generating the key

```
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

Store it only in the host's secret settings (for example the Render environment tab). Do not commit it, paste it in chat, or put it in `.env.example`.

**Key loss warning:** if the key is lost or changed, every stored document and every saved ID number becomes unreadable and cannot be recovered. Keep a copy in the team's password manager. There is no key rotation tool yet.

### Storage persistence

Files are encrypted and written to `KYC_STORAGE_DIR` on the server's filesystem. Render's filesystem is ephemeral unless a persistent disk is attached, so without one, every deploy or restart deletes the uploaded documents while the database rows remain.

`[OWNER TO DECIDE: Render persistent disk or object storage]`

Until that is decided, do not launch KYC (see below). If you use a disk, point `KYC_STORAGE_DIR` at its mount path. Back up the directory and the key separately.

## Settings

Stored in the database and read on every request, so changes apply at once without a restart. View with `GET /api/admin/kyc/settings` (super_admin or kyc_reviewer). Change with `PUT /api/admin/kyc/settings` (super_admin only). Send only the fields to change. Each change is recorded in the audit trail.

| Setting | Default | Meaning |
|---|---|---|
| `firstNudgeDays` | 1 | Days after the start of the first cycle for the first nudge. |
| `secondNudgeDays` | 7 | Days after the start for the second nudge. Must be later than the first. |
| `reminderIntervalDays` | 14 | Repeat reminder spacing, counted from the start of the cycle. |
| `warningBeforeDays` | 4 | The warning is sent this many days before the deadline. Must be less than `enforcementDays` and `resubmitGraceDays`. |
| `enforcementDays` | 60 | Days from the start of the first cycle until restriction. |
| `resubmitGraceDays` | 14 | Days a user gets to resubmit after a rejection, correction request or expiry. |
| `remindersEnabled` | true | Set to false to stop reminders being sent. Restriction still applies. |
| `rolloutAt` | null | Read only, set once by the launch endpoint (see "Launching KYC"). While it is null nobody has a deadline, gets reminders or is restricted. The first cycle starts at the later of the user's creation time and `rolloutAt`, so existing users get the full period from launch, not from when they signed up. A resubmission period that started before launch also counts from `rolloutAt`. |

The day fields are whole numbers from 1 to 365.

```
curl -s https://<HOST>/api/admin/kyc/settings -H "Authorization: Bearer <ADMIN_TOKEN>"

curl -s -X PUT https://<HOST>/api/admin/kyc/settings \
  -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" \
  -d '{"enforcementDays": 90, "reminderIntervalDays": 21}'
```

Super admins can also change these on the Settings tab of the KYC admin page.

## Launching KYC

Deploying this code does not start anyone's clock. KYC stays dormant (no deadlines, no reminders, no restriction; `GET /api/kyc/me` returns `"launched": false` and `"deadline": null`) until a super_admin launches it. Users can still save drafts and submit while it is dormant.

Launch is a deliberate rollout step. Do it only after all of these are true:

1. The storage decision above is made and `KYC_STORAGE_DIR` points at durable storage.
2. `KYC_ENCRYPTION_KEY` is set on every instance (the endpoint returns 503 without it).
3. The Stage 2b app, with the KYC screens, has shipped to users.
4. `LEGACY_USERID_ROUTES=false`, if restriction should apply (see Enforcement).

A super_admin can launch from the Settings tab of the KYC admin page (see "Admin page"), or with:

```
curl -s -X POST https://<HOST>/api/admin/kyc/settings/launch \
  -H "Authorization: Bearer <ADMIN_TOKEN>"
```

This sets `rolloutAt` to now, records a `SETTINGS_CHANGED` audit event and returns the settings. It can only happen once: a second call returns 409 `KYC has already been launched.` There is no un-launch endpoint. From launch, each user has `enforcementDays` (60 by default) before restriction.

## The reminder job

- Started inside the server process (`node index.js`), 10 seconds after boot and then every `KYC_JOB_INTERVAL_MS`. It does not run under tests or when the module is imported.
- Before launch each run does nothing.
- Each run scans users who are not yet submitted or approved, sends the reminder stage that is due, and records restriction for users past their deadline.
- With several instances, only one runs the job at a time. The holder takes a lease in the database that lasts twice the interval, so a crashed holder is replaced within two intervals.
- Idempotent: each reminder stage is recorded once per user per cycle under a unique key, and so is the restriction event. Re-running or running twice sends nothing twice. If a stage is skipped (for example the job was off) it is recorded as skipped and only the latest due stage is sent.
- To disable on an instance, set `KYC_JOB_ENABLED=false` and restart. To stop all reminders without a restart, set `remindersEnabled` to false.

## Enforcement

Cart routes and other protected routes use `requireKycAccess`. It checks the user's deadline on every request and returns:

```
403 {"code":"KYC_RESTRICTED","message":"Complete your KYC verification to keep using this feature.", ...}
```

Users who are approved, pending review, or hold an active exemption are not restricted. Nobody is restricted before launch, or while `KYC_ENCRYPTION_KEY` is missing (users could not complete KYC then).

**Prerequisite:** enforcement only applies to requests authenticated with an app session token. Legacy requests that send a bare `userId` (accepted while `LEGACY_USERID_ROUTES=true`) are not enforced. Set `LEGACY_USERID_ROUTES=false` before relying on KYC restrictions.

## Staff roles

| Role | Can do |
|---|---|
| `super_admin` | Everything below, plus changing settings and launching KYC. |
| `kyc_reviewer` | View the KYC list, details, documents and audit trail. Approve, reject, request correction, expire, grant exemptions, send manual reminders. Cannot change settings. Cannot manage shop data (products, categories, shops, banners, vouchers, FAQs, uploads or order status): those routes return 403. Signs in straight to the KYC page. |

Staff sign in at `POST /api/auth/login` and use the returned token as `<ADMIN_TOKEN>`. To create a reviewer, see "Creating a kyc_reviewer" under "Admin page".

## Admin page

The admin panel has a KYC page (`kyc.html`, linked as "KYC" in the sidebar of every admin page). Where the admin panel is hosted is outside this document.

Opening the admin panel as a local file (file://) does not work because the API only accepts requests from allowed origins; serve it over http(s) and add its origin to ALLOWED_ORIGINS.

### Who can see it

Only `super_admin` and `kyc_reviewer` accounts. For any other role the KYC link is hidden and the page shows "You don't have access to this." Hiding the link is only for convenience: the server checks the role on every `/api/admin/kyc` request and returns 403 to anyone else.

The role is read from the sign-in token, which lasts one day. A role change takes effect the next time that person signs in, so after removing someone's access, expect their current session to keep working for up to a day.

If a session ends while the page is open (the server returns 401), the page says "Your session ended. Sign in again." Anything typed in an open form stays on screen so it can be copied before signing in.

### Creating a kyc_reviewer

`POST /api/auth/register` (super_admin only) takes `username` and `password` and nothing else. It does **not** accept a `role`, so every account it creates is `staff`, which cannot open the KYC page. There is no endpoint or admin screen that changes a staff member's role.

To make someone a reviewer, an operator with database access has to set the role:

1. Create the account with the register endpoint, as a super_admin:
   ```
   curl -s -X POST https://<HOST>/api/auth/register \
     -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" \
     -d '{"username": "<REVIEWER_USERNAME>", "password": "<TEMPORARY_PASSWORD>"}'
   ```
   Your shell may save this command, including the password, in its history. Run it from a shell that doesn't keep history, or delete the line from the history file afterwards. There is no self-service password change yet, so the password you set here stays the reviewer's password until an operator replaces it.
2. Change its role, either with a one-off update in MongoDB on the `users` collection:
   ```
   db.users.updateOne({ username: "<REVIEWER_USERNAME>" }, { $set: { role: "kyc_reviewer" } })
   ```
   or with a small script written like `scripts/create-super-admin.js` that sets `role` to `kyc_reviewer` instead of `super_admin`.
3. The reviewer signs in to the admin panel. Share the password over a private channel. There is no self-service password change yet, so they keep this password until an operator replaces it.

`[OWNER TO DECIDE: keep role changes as an operator step, or add a reviewer script or a super_admin endpoint]`

### What each tab does

**Review queue.** The large number at the top is how many users are waiting for review. Below it are the counts for every status; select one to filter the list. Search by phone number or name, or filter by status. Each row shows the user's status, when they submitted, their last reminder and their deadline. On a phone each row becomes a card.

Select "Review" to open a user's panel. It shows their account, the latest submission (personal details, address, identification, documents and the decision so far), earlier submissions and recent activity. Depending on the user's status, the actions are:

| Status | Actions |
|---|---|
| Under review | Approve, Request correction, Reject |
| Verified | Mark expired |
| Not started, In progress, Not approved, Needs a correction, Expired | Send reminder (only if the user has a deadline), Grant exemption |

A restricted user gets the actions for the status underneath the restriction (for example Not approved).

Reject, Request correction and Mark expired need a reason of 5 to 500 characters. The user sees the reason for a rejection or correction in their notification. An exemption needs an end date (up to 90 days ahead) and a reason. If another reviewer changed the same user first, the action stops, the dialog says so and the panel reloads.

**Settings.** Shows whether KYC is launched and the reminder and deadline settings (see "Settings" above). A `kyc_reviewer` can read them only. A `super_admin` can edit and save them, and sees the Launch section while KYC is not launched.

**Audit log.** Every KYC event, newest first. Filter by event type, or by a user's 24-character ID (shown on each event). "Open in audit log" in a user's panel opens this tab filtered to that user.

### Launching from the page

While KYC is not launched, a super_admin sees a "Launch KYC" section on the Settings tab. Type `LAUNCH` and select "Launch KYC". The button stays disabled while there are unsaved settings changes.

Launching cannot be undone. It does the same as the launch endpoint: everyone who has not verified or submitted gets the deadline from today. Check every item in "Launching KYC" first. `KYC_ENCRYPTION_KEY` must be set, or the launch fails (the server returns 503) and nothing changes.

### Documents and ID numbers

- Every document the page loads is recorded in the audit log as `DOCUMENT_VIEWED`, with the reviewer and the document. This includes the small previews in the panel, so opening a user's panel records one event per image document, and expanding an earlier submission records its images too. Opening an image in the viewer reuses that preview, so it is not recorded a second time. The panel's activity list groups these into one line; the audit log keeps every event.
- ID numbers are masked. "Reveal" asks for confirmation, records `ID_REVEALED`, and shows the number until the panel closes. It is not stored in the browser.
- Images open in a viewer inside the page. PDFs open in a new browser tab, because the page does not run the browser's PDF viewer inside itself. That tab shows a temporary copy that stops working once the document viewer is closed. To see the PDF again, open it again from the panel (this is recorded again).

## Endpoints

### User (app session token required)

| Method and path | Purpose |
|---|---|
| `GET /api/kyc/me` | Status, whether KYC is launched, deadline, progress, missing fields, masked draft, documents, history. |
| `PUT /api/kyc/draft` | Save draft details as `{"data": {...}}`. Partial saves merge. |
| `POST /api/kyc/documents` | Upload a file (multipart: `kind`, `file`). Kinds: `id_front`, `id_back`, `passport_bio`, `proof_of_residence`. Type is checked from the file bytes. |
| `GET /api/kyc/documents/:id` | Download the user's own draft document. |
| `DELETE /api/kyc/documents/:id` | Remove a draft document. |
| `POST /api/kyc/submit` | Validate everything and submit for review. 400 lists the missing fields. |

Uploads are limited to 30 per hour per user. Draft saves and submits share a limit of 60 per hour per user. Over the limit the response is 429.

### Notifications (app session token required)

| Method and path | Purpose |
|---|---|
| `GET /api/notifications` | The user's inbox, newest first, with the unread count. |
| `POST /api/notifications/:id/read` | Mark one notification read. |

### Admin (`super_admin` or `kyc_reviewer`)

| Method and path | Purpose |
|---|---|
| `GET /api/admin/kyc/stats` | Counts by status. |
| `GET /api/admin/kyc/users` | List users. Query: `q`, `status`, `page`, `limit`. |
| `GET /api/admin/kyc/users/:id` | Detail with submissions and events. `?reveal=1` includes the ID number and is audited. |
| `GET /api/admin/kyc/documents/:id` | View a submitted document (audited). |
| `POST /api/admin/kyc/users/:id/approve` | Approve a pending submission. |
| `POST /api/admin/kyc/users/:id/reject` | Reject. Body `{"reason": "..."}`, 5 to 500 characters. Starts a resubmission period. |
| `POST /api/admin/kyc/users/:id/request-correction` | Ask for a correction. Body `{"reason": "..."}`. |
| `POST /api/admin/kyc/users/:id/expire` | Expire an approved KYC so the user renews. Body `{"reason": "..."}`. |
| `POST /api/admin/kyc/users/:id/exemption` | Pause enforcement. Body `{"until": "<ISO date>", "reason": "..."}`, at most 90 days. |
| `POST /api/admin/kyc/users/:id/remind` | Send a reminder now (once per hour per user). |
| `GET /api/admin/kyc/settings` | Read settings. |
| `PUT /api/admin/kyc/settings` | Change settings (`super_admin` only). |
| `POST /api/admin/kyc/settings/launch` | Launch KYC once (`super_admin` only). |
| `GET /api/admin/kyc/audit` | Audit trail. Query: `appUserId`, `type`, `page`. |

## Lifecycle walkthrough

Placeholders only. `<USER_TOKEN>` is an app session token, `<ADMIN_TOKEN>` a staff token, `<USER_ID>` the user's AppUser id from the admin list.

1. Check the user's state:
   ```
   curl -s https://<HOST>/api/kyc/me -H "Authorization: Bearer <USER_TOKEN>"
   ```
2. Save the details:
   ```
   curl -s -X PUT https://<HOST>/api/kyc/draft -H "Authorization: Bearer <USER_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{"data":{"personal":{"firstName":"<FIRST>","lastName":"<LAST>","dateOfBirth":"<YYYY-MM-DD>","gender":"female","nationality":"<NATIONALITY>"},"address":{"line1":"<ADDRESS>","city":"<CITY>","country":"<COUNTRY>"},"identification":{"idType":"national_id","idNumber":"<ID_NUMBER>"}}}'
   ```
3. Upload the documents (national ID needs front and back, a passport needs `passport_bio`):
   ```
   curl -s -X POST https://<HOST>/api/kyc/documents -H "Authorization: Bearer <USER_TOKEN>" \
     -F kind=id_front -F file=@<FRONT_IMAGE>
   curl -s -X POST https://<HOST>/api/kyc/documents -H "Authorization: Bearer <USER_TOKEN>" \
     -F kind=id_back -F file=@<BACK_IMAGE>
   ```
4. Submit. A 400 lists what is missing, 201 returns `PENDING_REVIEW`:
   ```
   curl -s -X POST https://<HOST>/api/kyc/submit -H "Authorization: Bearer <USER_TOKEN>"
   ```
5. A reviewer approves (or rejects with a reason):
   ```
   curl -s -X POST https://<HOST>/api/admin/kyc/users/<USER_ID>/approve \
     -H "Authorization: Bearer <ADMIN_TOKEN>"
   ```
6. The user receives an `APPROVED` notification, and `GET /api/kyc/me` shows `APPROVED`. The draft and its working copies are removed.

To test enforcement without waiting 60 days, use a throwaway database: launch KYC, set `rolloutAt` in the settings document to more than `enforcementDays` ago, insert an AppUser whose `createdAt` is also older than that, sign a token for it, and call `GET /api/cart`. Expect 403 `KYC_RESTRICTED`. Run steps 2 to 5 for that user and the same call returns 200. This needs `LEGACY_USERID_ROUTES=false`.

## Retention

Submitted documents and details are kept while the account is active. After that, delete them:

`[CONFIRM WITH COMPLIANCE: retention period]`

`scripts/kyc-purge-user.js` deletes one user's KYC data. It is run by hand and is not scheduled. It removes the draft, documents (rows and encrypted files), submissions and notifications. Audit events are kept, with the `data` of each event emptied (type, actor and time stay). The user's KYC status is left as it is.

Always run the dry run first. It prints counts only (no names, ids or document content) and deletes nothing:

```
cd backend
MONGO_URI=<MONGO_URI> KYC_STORAGE_DIR=<KYC_STORAGE_DIR> node scripts/kyc-purge-user.js <SIP_USERNAME>
MONGO_URI=<MONGO_URI> KYC_STORAGE_DIR=<KYC_STORAGE_DIR> node scripts/kyc-purge-user.js <SIP_USERNAME> --apply
```

The username is normalised the same way as at sign-in, so `+263...` and `263...` find the same user. Back up first if there is any doubt: this cannot be undone.
