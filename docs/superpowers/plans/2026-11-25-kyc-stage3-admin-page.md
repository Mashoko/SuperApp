# KYC Stage 3: Admin KYC Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give KYC reviewers and super admins a KYC page in the existing admin panel: overview stats, a searchable review queue, a review panel with document viewing and approve / reject / request-correction / expire actions, exemptions, manual reminders, settings with the one-time launch, and the audit log.

**Architecture:** One new page `admin-panel/kyc.html` with its own script `kyc.js` and stylesheet `kyc.css`, plus a small shared module `kyc-lib.js` holding the logic that can be unit-tested (API wrapper, safe DOM builder, labels, formatting, validation). It calls the Stage 2a admin API at `${CONFIG.API_URL}/admin/kyc/*` with the staff JWT already stored by `login.html`. No build step, no framework, no new dependencies.

**Tech Stack:** Plain HTML/CSS/JavaScript (matching the existing admin panel); unit tests for `kyc-lib.js` run with the backend's Jest (`backend/tests/admin_kyc_lib.test.js`); visual checks with headless Chrome.

**Spec:** `docs/superpowers/specs/2026-11-22-kyc-verification-design.md` §6.9 (and §7 of the original requirements: overview statistics, management table, administrative controls). API: `backend/kyc/routes/kyc_admin.routes.js`, `backend/docs/kyc.md`.

## Global Constraints

- API contract (read `kyc_admin.routes.js` for exact shapes before coding): `GET /stats`, `GET /users?q&status&page&limit`, `GET /users/:id[?reveal=1]`, `GET /documents/:id`, `POST /users/:id/{approve|reject|request-correction|expire|exemption|remind}`, `GET|PUT /settings`, `POST /settings/launch`, `GET /audit?appUserId&type&page`. Roles: `super_admin` and `kyc_reviewer`; settings PUT and launch are `super_admin` only.
- Security (binding):
  - Never insert server or user data with `innerHTML`, `outerHTML`, `insertAdjacentHTML` or template strings into HTML. Build DOM with `document.createElement` + `textContent` (via `kyc-lib.js` `el()`). Grep must find no `innerHTML` in `kyc.js`/`kyc-lib.js` except clearing a container with `replaceChildren()` (preferred) .
  - Documents are fetched with the Authorization header and shown from a `blob:` object URL; revoke object URLs when the viewer closes. Never put the token in a URL. PDFs open in an `<iframe sandbox>` (no `allow-scripts`) or a new tab from the blob; images in `<img>`.
  - Revealing an ID number needs an explicit confirm ("Reveal ID number? This is recorded in the audit log.") and is never cached beyond the open panel.
  - On 401 → clear token and go to `login.html` (same as other pages). On 403 → show "You don't have access to this." in place of the content.
- Visibility: the "KYC" nav item is added to every admin page's sidebar; it (and the page) is shown only when `JSON.parse(localStorage.user).role` is `super_admin` or `kyc_reviewer` (UI only; the server enforces). Settings editing and Launch controls render only for `super_admin`.
- Design (owner's standards, binding for the new page; the existing glass/gradient pages are NOT restyled in this stage): `kyc.css` scopes everything under `body.kyc-page` and overrides the global gradient background with a flat neutral (`#F7F7F8` light); one flat accent (`#10B981`, the panel's existing primary) used only for the primary action and focus; status colours only on status badges; hairline 1 px borders (`#E4E4E7`), no shadows except on dialogs/drawer; radius 8 on cards/buttons/dialogs, 6 on inputs/badges; no gradients, glows, emoji or pill buttons; one primary element per view; body text 16 px, table text ≥ 14 px with tabular numerals for counts/dates; visible focus rings; WCAG AA contrast; no em dashes in copy.
- Dashboard checklist: the overview shows ONE primary metric large ("Pending review" count, with the label "Waiting for review") and the other counts small in one row; no coloured icon tiles; numbers in tabular digits.
- Responsive: works at 375, 768 and 1280 px; under 640 px each table row becomes a card with name, status badge and deadline visible without horizontal scroll; touch targets ≥ 44 px under `(pointer: coarse)`; the review panel becomes full-screen under 768 px.
- Every async view has loading, empty and error (with retry) states.
- Dates: local time, `Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })`; timestamps in tables `d MMM y, HH:mm`.
- Status labels (same as the app): NOT_STARTED "Not started", IN_PROGRESS "In progress", PENDING_REVIEW "Under review", APPROVED "Verified", REJECTED "Not approved", REQUIRES_CORRECTION "Needs a correction", EXPIRED "Expired", RESTRICTED "Restricted".
- No `console.log` of personal data. No new dependencies.

## Review Focus

- A user's name or a reviewer reason containing `<img src=x onerror=alert(1)>` renders as literal text everywhere (table, panel, audit log, dialogs). Test in Task 1 (el()) and checked in Task 5.
- Two reviewers act on the same submission: the second gets the server's 409 message shown in the panel and the row refreshes to the real status. Handled in Task 3.
- Token expires while the review panel is open: the next action redirects to login without losing the reason the reviewer typed silently (warn "Your session ended. Sign in again."). Task 3.
- Large document (8 MB PDF) on a slow link: viewer shows a loading state and a failure message with retry; closing the viewer cancels the fetch (AbortController) and revokes the object URL. Task 3.
- Launch pressed twice / by two admins: the second sees "KYC has already been launched." and the button disables. Task 4.

---

### Task 1: Shared KYC admin library

**Files:**
- Create: `admin-panel/kyc-lib.js`
- Test: `backend/tests/admin_kyc_lib.test.js`

**Interfaces:**
- `kyc-lib.js` works in the browser (attaches `window.KycLib`) and in Node (`module.exports`) without a bundler: `(function (root, factory) { … })(…)` pattern.
- Produces:
  - `el(tag, props?, ...children)` → Element. `props` may set `className`, `id`, `type`, `name`, `value`, `href`, `aria-*`, `data-*`, `disabled`, `hidden`, `title`, and `on: { click: fn, … }`; children are Nodes or strings (strings become text nodes). Rejects props named `innerHTML`/`outerHTML` (throws). Never parses HTML.
  - `statusLabel(code)`, `statusTone(code)` → `'neutral'|'info'|'success'|'warning'|'danger'` (NOT_STARTED/IN_PROGRESS neutral, PENDING_REVIEW info, APPROVED success, REQUIRES_CORRECTION/EXPIRED warning, REJECTED/RESTRICTED danger).
  - `formatDate(iso)`, `formatDateTime(iso)` (local; `''` for null/invalid).
  - `validateReason(text)` → `{ ok, value, error }` mirroring the server: trim, strip one trailing full stop, 5–500 chars; error "Give a reason between 5 and 500 characters.".
  - `validateExemption({ until, reason }, now)` → until strictly future and ≤ 90 days ahead ("Choose a date within the next 90 days."), reason via `validateReason`.
  - `validateSettings(merged)` → mirrors the server rules (integers 1–365; secondNudgeDays > firstNudgeDays; warningBeforeDays < enforcementDays; resubmitGraceDays > warningBeforeDays; remindersEnabled boolean) → `{ ok, errors: { field: message } }`.
  - `createApi({ baseUrl, getToken, onUnauthorized, fetchImpl = fetch })` → `{ get(path, { signal }), post(path, body), put(path, body), blob(path, { signal }) }`; adds `Authorization: Bearer`; JSON in/out; on 401 calls `onUnauthorized()` and throws `ApiError(401, 'Your session ended. Sign in again.')`; other non-2xx throw `ApiError(status, serverMessage || 'Something went wrong. Please try again.')`; network failure → `ApiError(0, 'No connection. Check your internet and try again.')`.
  - `currentRole()` from `localStorage.user` (defensive parse; `null` if absent).

- [ ] **Step 1: Failing tests** (Jest, `testEnvironment` node; for `el()` use a tiny fake document or `jsdom` ONLY if already installed in backend devDependencies — check first; if not, test `el()` against a minimal hand-written fake `document` exposing `createElement`/`createTextNode` and record calls): `el` turns `'<img src=x onerror=alert(1)>'` into a text node (never parsed); `el` throws for `innerHTML` prop; status labels/tones for all 8 codes; date formatting null/invalid; reason trimming, trailing full stop, bounds; exemption bounds at 90 days; settings rule violations each produce the right field error; API adds bearer, maps 401 (calls onUnauthorized), 409 server message, network error, and passes `signal`.
- [ ] **Step 2:** `cd backend && npx jest --runInBand tests/admin_kyc_lib.test.js` — FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Test file + full backend suite PASS, clean exit.
- [ ] **Step 5:** Commit `Add shared KYC admin library`.

### Task 2: KYC page shell, overview and review queue

**Files:**
- Create: `admin-panel/kyc.html`, `admin-panel/kyc.css`, `admin-panel/kyc.js`
- Modify: every admin page's sidebar (`index.html`, `categories.html`, `shops.html`, `banners.html`, `vouchers.html`, `faqs.html`) to add `<a href="kyc.html" class="nav-item" data-requires-role="super_admin kyc_reviewer">KYC</a>`; `admin-panel/config.js` (hide `[data-requires-role]` elements whose roles don't include `currentRole()` after DOMContentLoaded)

**Interfaces:**
- `kyc.html`: same head pattern as other pages (token check → login), loads `config.js`, `kyc-lib.js`, `kyc.js`; `<body class="kyc-page">`; sidebar with KYC active; top bar; main region with tabs: "Review queue" (default), "Settings", "Audit log" (Task 4 fills the last two; render placeholders now). If role isn't allowed: show "You don't have access to this." and no data calls.
- Overview (top of Review queue): primary metric "Waiting for review" = `pendingReview` large; secondary row (small, tabular): Total, Verified, Not started, In progress, Needs a correction, Not approved, Expired, Restricted. Clicking a secondary count sets the status filter.
- Queue: search input (label "Search by phone or name", debounced 300 ms, max 64 chars), status select (All + 8 statuses), table columns: User (displayName, phone below), Registered, Status (badge), Submitted, Last reminder, Deadline, Actions ("Review" button). Pagination: Previous / "Page X of Y" / Next, 25 per page. Default sort as the API returns. Keep filters in the URL query (`?q=&status=&page=`) so refresh/back keep state.
- Under 640 px: rows render as cards (name, status badge, deadline line, Review button).
- States: loading skeleton rows, empty "No users match these filters." with "Clear filters", error with "Try again".

- [ ] **Step 0: Build the local harness (scratchpad, not committed; reused by Tasks 3–5):** a seed + serve script that starts the backend with mongodb-memory-server, sets `JWT_SECRET` and a fresh `KYC_ENCRYPTION_KEY`, creates a `super_admin`, a `kyc_reviewer` and a `staff` user (print their throwaway passwords to the console only), ~40 AppUsers across all statuses with submissions and real PNG/PDF uploads (fake names, fake phones `26377000xxxx`), one user whose displayName and rejection reason are `<img src=x onerror=alert(1)>`, launches KYC, and serves `admin-panel/` on `http://localhost:8098` (config.js already points localhost at `http://localhost:5000/api`; run the backend on 5000 and make sure CORS allows `http://localhost:8098` via `ALLOWED_ORIGINS`). Write its path and usage into the task report.
- [ ] **Step 1:** Add the page skeleton and nav items; verify against the harness that the role gate works (staff role sees the no-access message; kyc_reviewer sees the queue).
- [ ] **Step 2:** Implement overview + queue with kyc-lib `el()` only (grep: no `innerHTML` in kyc.js).
- [ ] **Step 3:** Manual check against the local backend with seeded users across all statuses (Task 5 harness): filters, search, pagination, URL state, mobile cards at 375 px.
- [ ] **Step 4:** Commit `Add KYC review queue to the admin panel`.

### Task 3: Review panel, documents and actions

**Files:**
- Modify: `admin-panel/kyc.js`, `admin-panel/kyc.css`

**Interfaces:**
- "Review" opens a right-side panel (full-screen under 768 px) for `GET /users/:id`: heading = display name + status badge; facts list (phone, registered, deadline, exemption until); latest submission first: personal, address, identification (ID number masked + "Reveal" text button → confirm → `?reveal=1` → shows the number in the panel only), documents (thumbnail for images via blob; "Open PDF" for PDFs), decision/reason; earlier submissions collapsed; recent events (type, actor, time).
- Document viewer: modal; fetch via `api.blob` with an AbortController; loading spinner, error + retry; image fit-to-screen with zoom toggle; PDF in `<iframe sandbox>` from the blob URL; Esc/Close revokes the URL and aborts.
- Actions (buttons by status): PENDING_REVIEW → primary "Approve", secondary "Request correction", "Reject"; APPROVED → "Mark expired"; restrictable statuses → "Send reminder", "Grant exemption". Reason dialog for reject/correction/expire (textarea with live count, validated with `validateReason`, server errors shown inline); exemption dialog (date input min tomorrow / max today+90, reason). Approve asks "Approve this verification?" confirm.
- After any action: show the server result, refresh the panel, the row and the overview. 409 → show the server message and refresh. 401 → keep the dialog text in memory, show "Your session ended. Sign in again." with a "Sign in" button (navigates to login).
- Keyboard: panel and dialogs trap focus, Esc closes (dialogs first), focus returns to the triggering button; dialogs use `<dialog>` with `aria-labelledby`.

- [ ] **Step 1:** Implement the panel and viewer; check against the local backend with real seeded uploads (PNG and PDF) that thumbnails and the PDF viewer work, object URLs are revoked (check `URL.revokeObjectURL` is called), and the network tab never shows the token in a URL.
- [ ] **Step 2:** Implement actions and dialogs; check each action end to end against the local backend (approve → row shows Verified; reject with a reason → Not approved; correction; expire; exemption; remind twice → second shows "A reminder was sent in the last hour."; concurrent approve from two tabs → second shows the 409 message).
- [ ] **Step 3:** XSS check: seed a user whose displayName and a rejection reason are `<img src=x onerror=alert(1)>`; confirm it renders as text in table, panel, events and audit log (no dialog/alert).
- [ ] **Step 4:** Commit `Add KYC review panel, document viewer and review actions`.

### Task 4: Settings, launch and audit log

**Files:**
- Modify: `admin-panel/kyc.js`, `admin-panel/kyc.css`

**Interfaces:**
- Settings tab: shows current values with labels and help text: "First reminder (days after start)", "Second reminder (days)", "Reminder interval (days)", "Final warning (days before deadline)", "Deadline (days to complete KYC)", "Resubmission window (days)", "Reminders on". Read-only for `kyc_reviewer`. For `super_admin`: editable number inputs, client validation via `validateSettings`, "Save changes" primary, server errors per field, success "Settings saved." Shows "Launched on {date}" or "KYC is not launched. Nobody has a deadline yet."
- Launch (super_admin, not launched): a separate bordered section "Launch KYC" explaining in plain words that launching starts everyone's {enforcementDays}-day deadline today and cannot be undone; requires typing `LAUNCH` to enable the "Launch KYC" button; on success refresh settings; 409 → "KYC has already been launched."; 503 → "KYC is temporarily unavailable." (server key missing).
- Audit log tab: filters (type select with the event types, "User ID" text optional, prefilled when opened from a user's panel), list (time, type, actor, user, short data summary rendered as text key: value pairs, never raw HTML), pagination 50/page, empty/error states.

- [ ] **Step 1:** Implement settings (both roles) and launch; check against the local backend: reviewer sees read-only; super_admin saves a valid change (value persists after reload), invalid combination blocked client-side and server-side; launch flow with typed confirmation; second launch shows the message.
- [ ] **Step 2:** Implement audit log; check filters and pagination against seeded events.
- [ ] **Step 3:** Commit `Add KYC settings, launch and audit log to the admin panel`.

### Task 5: Local harness, visual check and docs

**Files:**
- Reuse: the Task 2 harness (scratchpad).
- Modify: `backend/docs/kyc.md` (add "Admin page" section: who can see it, how to create a kyc_reviewer with the existing super_admin register API, the launch step now available in the UI)

- [ ] **Step 1:** Run the Task 2 harness. If the Playwright MCP is available use it; otherwise drive Chrome via the DevTools Protocol from a scratchpad Node script (Node's built-in WebSocket + `google-chrome --headless=new --remote-debugging-port`) to log in, navigate and capture screenshots. Capture: overview + queue, filtered queue, empty state, review panel (pending, rejected), document viewer (image, PDF), reason dialog with error, exemption dialog, settings (reviewer read-only, super_admin edit), launch section, audit log — at 375, 768 and 1280 px. Save PNGs in the scratchpad.
- [ ] **Step 2:** Look at every screenshot for overflow, hierarchy (one primary), contrast, banned patterns, the mobile card layout and the full-screen panel under 768 px. Fix defects with separate commits.
- [ ] **Step 3:** Grep checks: no `innerHTML`/`insertAdjacentHTML`/`outerHTML` in `kyc.js`/`kyc-lib.js`; no `console.log`; no em dashes in copy.
- [ ] **Step 4:** Backend suite PASS (includes `admin_kyc_lib.test.js`).
- [ ] **Step 5:** Commit `Document the KYC admin page`.

---

After Stage 3: the emergency-call FAILED fallback fix (from the Stage 2b final review) gets its own small plan.
