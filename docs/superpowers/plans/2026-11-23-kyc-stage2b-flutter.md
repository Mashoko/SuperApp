# KYC Stage 2b: Flutter KYC Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give app users the full KYC experience on top of the Stage 2a API: a resumable multi-step form with document upload, a status page, reminders, a non-dismissible mandatory screen when restricted, and a lock on outgoing calls (emergency numbers always allowed).

**Architecture:** A `KycService` (HTTP, through Stage 1's `AuthedHttpClient`) and a single `KycStatusController` (ChangeNotifier, registered in get_it and provided at the root) hold KYC state for the whole app. `AuthedHttpClient` reports any `403 KYC_RESTRICTED` to the controller. A `KycGate` placed in `MaterialApp.builder` covers every screen with the mandatory flow while restricted. The call lock sits in the `MakeCall` use case, which every outgoing call goes through.

**Tech Stack:** Flutter (package `mvvm_sip_demo`), Provider + get_it, `http` (+ `package:http/testing.dart`), `shared_preferences`, `image_picker`, `file_picker`, `intl`. No new dependencies. Backend Task 0: Express/Jest.

**Spec:** `docs/superpowers/specs/2026-11-22-kyc-verification-design.md` (6.5, 6.7, 6.8). API reference: `backend/docs/kyc.md` and `backend/kyc/routes/kyc_user.routes.js`, `notifications.routes.js`.

## Global Constraints

- Never run the full `flutter test` (`test/grpc_balance_test.dart` makes live recharge calls on a real account). Run targeted files: `flutter test test/<path>` for the files you touch, plus `flutter test test/core test/features test/services test/models` for a broad pass. Pre-existing failures: 6 in `test/features/home/explore_tab_test.dart`.
- No new packages. HTTP only through `AuthedHttpClient` (from get_it).
- API base: the same `https://superapp-diht.onrender.com/api` constant pattern as existing services (define once in `KycService`).
- `/api/kyc/me` contract: `{ launched, status, underlyingStatus, deadline (ISO|null), exemptUntil, progress (0–100), outstanding: string[], draft, documents: [{id,kind,mime,size,createdAt}], history: [{version,submittedAt,decision,decidedAt,reason}], rejectionReason, correctionNotes, phone }`. Statuses: NOT_STARTED, IN_PROGRESS, PENDING_REVIEW, APPROVED, REJECTED, REQUIRES_CORRECTION, EXPIRED, and computed RESTRICTED.
- KYC is shown only when `launched == true`. When `launched == false` the app shows no banners, sheets or gate (the status page may still be reached from Profile and says "Verification is not open yet.").
- Restricted = `status == 'RESTRICTED'` from `/me`, or any `403` whose body `code == 'KYC_RESTRICTED'`.
- Emergency numbers always callable `[CONFIRM WITH COMPLIANCE]`: `999`, `993`, `994`, `995`, `112` — compared after stripping everything but digits. Incoming calls are never touched.
- Dates shown in the user's local time, `DateFormat('d MMMM y')` (e.g. `22 January 2027`).
- Design (owner's standards, binding): one flat accent = `Theme.of(context).colorScheme.primary`; no gradients, glows, emoji or pill buttons (radius 8 for cards and buttons, 6 for inner elements); hairline borders (`colorScheme.outlineVariant`, 1 px) instead of shadows, shadows only on sheets/dialogs; one primary element per screen; body text ≥ 16 px; input text ≥ 16 px; touch targets ≥ 44 × 44; correct keyboards (`TextInputType.name`, `.streetAddress`, `.datetime` via date picker); labels on every field; visible focus; WCAG AA contrast in light and dark theme; no em dashes in copy; layouts work at 375, 768 and 1280 logical px wide without overflow.
- Every async screen has loading, empty and error states with a retry.
- No `print` of tokens, ID numbers or form data.

## Review Focus

- App resumes from background after the deadline passed: the gate appears on the next KYC refresh or the next 403, without a restart. Test in Task 2.
- User loses network mid-upload: the upload shows an error with retry, the draft is intact, nothing is half-saved. Test in Task 4.
- Restricted user presses Android back on the mandatory screen: nothing happens (no route pops behind it). Test in Task 6.
- Number typed as `+999` or `99 9`: still treated as emergency (digits-only compare) and allowed while restricted; `0999123` is not. Test in Task 3.
- Server returns field errors on submit after the client thought the form was complete: errors map to the right step and field, and the form jumps to the first failing step. Test in Task 4.

---

### Task 0 (backend): Pre-launch rejection notifications

**Files:**
- Modify: `backend/kyc/notifications.js` (templates), `backend/kyc/routes/kyc_admin.routes.js` (only if it must choose the variant)
- Test: `backend/tests/kyc.admin_api.test.js` (or `notifications.test.js`)

**Interfaces:**
- When `deadline` is null, REJECTED, CORRECTION_REQUESTED and EXPIRED use these bodies (titles unchanged):
  - `REJECTED`: "Reason: {reason}. Please correct your details and submit again."
  - `CORRECTION_REQUESTED`: "{reason}. Please update your details and submit again."
  - `EXPIRED`: "Your verified details have expired. Please submit updated details."
  With a deadline, the existing bodies are unchanged.

- [ ] **Step 1: Failing tests:** `reject before launch delivers a REJECTED notification without a date`; same for request-correction and expire; `reject after launch still includes the deadline date`.
- [ ] **Step 2:** `cd backend && npx jest --runInBand tests/kyc.admin_api.test.js` — FAIL.
- [ ] **Step 3:** Implement (a `render` that picks the no-deadline body when `deadline` is null; `REMINDER`, `WARNING`, nudges keep requiring a deadline).
- [ ] **Step 4:** Full backend suite — PASS, clean exit.
- [ ] **Step 5:** Commit `Send rejection notices before KYC launch without a deadline`.

### Task 1: KYC service, models and restriction hook

**Files:**
- Create: `lib/features/kyc/data/kyc_models.dart`, `lib/features/kyc/data/kyc_service.dart`
- Modify: `lib/core/services/authed_http_client.dart` (restriction callback), `lib/core/di/inject.dart` (register `KycService`)
- Test: `test/features/kyc/kyc_service_test.dart`, extend `test/core/services/authed_http_client_test.dart`

**Interfaces:**
- Produces models (immutable, `fromJson`): `KycStatus { bool launched; String status; String underlyingStatus; DateTime? deadline; DateTime? exemptUntil; int progress; List<String> outstanding; KycDraft draft; List<KycDocumentInfo> documents; List<KycHistoryEntry> history; String? rejectionReason; String? correctionNotes; String phone; bool get isRestricted; bool get isVerified; bool get isPendingReview; bool get canEdit }`; `KycDraft { personal {firstName,lastName,dateOfBirth,gender,nationality}, address {line1,line2,city,country}, identification {idType, idNumberMasked, idExpiry} }` with `toJson()` that sends `idNumber` only when the user typed a new one; `KycDocumentInfo { id, kind, mime, size, createdAt }`; `KycHistoryEntry`; `KycNotification { id, kind, title, body, createdAt, readAt }`; `KycFieldErrors` (`Map<String,String>` keyed like `personal.firstName`).
- `KycService`:
  - `Future<KycStatus> getStatus()`
  - `Future<void> saveDraft(KycDraft draft)` — PUT `/kyc/draft` `{ data }`
  - `Future<KycDocumentInfo> uploadDocument({ required String kind, required List<int> bytes, required String filename, void Function(double)? onProgress })` — multipart `file` + `kind`
  - `Future<void> deleteDocument(String id)`
  - `Future<Uint8List> fetchDocument(String id)` (for previews of already-uploaded files)
  - `Future<void> submit()` — throws `KycValidationException(KycFieldErrors)` on 400 with `errors`
  - `Future<({List<KycNotification> items, int unread, int totalPages})> listNotifications({int page = 1})`, `Future<void> markRead(String id)`
  - All non-2xx → `KycApiException(statusCode, message)` using the server's `message` (fallback "Something went wrong. Please try again."); 413 → "This file is too large. Use a file under 8 MB."; 415 → "Upload a JPEG, PNG or PDF file."; 429 → "Too many attempts. Please wait a few minutes."; 503 → "Verification is temporarily unavailable. Please try again later."; network errors → "No connection. Check your internet and try again."
- `AuthedHttpClient`: add `void Function()? onKycRestricted` (settable after construction); invoke it when a response is 403 and its JSON body has `code == 'KYC_RESTRICTED'` (parse defensively; never throw from the hook).

- [ ] **Step 1: Failing tests** (`MockClient`): parses a full `/me` fixture; `isRestricted` true for `status: RESTRICTED`; `saveDraft` sends `idNumber` only when changed; upload sends multipart with `kind` and filename; submit 400 → `KycValidationException` with field map; 413/415/429/503/network map to the exact messages; notifications parse; `AuthedHttpClient` calls `onKycRestricted` once for a 403 KYC_RESTRICTED body and not for other 403s.
- [ ] **Step 2:** `flutter test test/features/kyc/kyc_service_test.dart test/core/services/authed_http_client_test.dart` — FAIL.
- [ ] **Step 3:** Implement; register `KycService` lazily in `inject.dart`.
- [ ] **Step 4:** Same tests PASS; `flutter analyze lib/features/kyc lib/core/services` no new issues.
- [ ] **Step 5:** Commit `Add KYC service, models and restriction hook`.

### Task 2: App-wide KYC status controller

**Files:**
- Create: `lib/features/kyc/presentation/kyc_status_controller.dart`
- Modify: `lib/core/di/inject.dart` (register singleton; wire `AuthedHttpClient.onKycRestricted = controller.markRestricted`), `lib/main.dart` (add `ChangeNotifierProvider.value` for the controller; refresh on `AppLifecycleState.resumed`)
- Test: `test/features/kyc/kyc_status_controller_test.dart`

**Interfaces:**
- `class KycStatusController extends ChangeNotifier { KycStatus? status; bool loading; String? error; bool get launched; bool get isRestricted; Future<void> refresh(); void markRestricted(); void clear(); }`
  - `refresh()` is single-flight (concurrent calls share one request) and ignores 401 (not signed in → `clear()`).
  - `markRestricted()` sets a restricted flag immediately (so the gate shows without waiting) and schedules `refresh()`.
  - `clear()` on logout (call it where `BackendSessionService.clear()` is called).
  - Refresh triggers: after successful sign-in (same place the backend session is started), app resume, after submit, and every 30 minutes while the app is in the foreground (`Timer`, cancelled on dispose/background).

- [ ] **Step 1: Failing tests** (fake `KycService`): refresh populates status; concurrent refreshes make one call; 401 clears; `markRestricted` flips `isRestricted` before the refresh completes; resume triggers refresh (call the lifecycle handler directly); timer refreshes after 30 minutes (`fake_async`); errors set `error` and keep the last good status.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement + wire. **Step 4:** PASS; analyze clean.
- [ ] **Step 5:** Commit `Add app-wide KYC status controller`.

### Task 3: Outgoing call lock with emergency allowlist

**Files:**
- Create: `lib/features/kyc/domain/emergency_numbers.dart`
- Modify: `lib/features/call/domain/usecases/make_call.dart`, `lib/core/di/inject.dart`
- Test: `test/features/kyc/emergency_numbers_test.dart`, `test/features/call/make_call_test.dart`

**Interfaces:**
- `bool isEmergencyNumber(String raw)` — digits-only equals one of the list.
- `MakeCall(this.repository, {bool Function()? isKycRestricted})`; when `isKycRestricted?.call() == true` and the destination is not an emergency number, return `Failure('Calls are paused until you complete your KYC verification. Emergency calls still work.')` without touching the repository. DI passes `() => getIt<KycStatusController>().isRestricted`.
- Callers already surface `Failure.message` (CallViewModel returns it); no UI change needed beyond that.

- [ ] **Step 1: Failing tests:** `999`, `+999`, `99 9`, `112` are emergency; `0999123`, `9990`, `` are not; restricted + normal number → Failure with the exact message and repository not called; restricted + `999` → repository called; not restricted → repository called.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** PASS (+ existing call tests).
- [ ] **Step 5:** Commit `Pause outgoing calls while KYC is restricted`.

### Task 4: Multi-step KYC form with autosave and uploads

**Files:**
- Create: `lib/features/kyc/presentation/kyc_form_view.dart`, `lib/features/kyc/presentation/kyc_form_viewmodel.dart`, `lib/features/kyc/presentation/widgets/kyc_step_indicator.dart`, `lib/features/kyc/presentation/widgets/kyc_document_tile.dart`, `lib/features/kyc/domain/kyc_validation.dart`
- Test: `test/features/kyc/kyc_validation_test.dart`, `test/features/kyc/kyc_form_viewmodel_test.dart`, `test/features/kyc/kyc_form_view_test.dart`

**Interfaces:**
- `kyc_validation.dart` mirrors server rules (backend/kyc/validation.js): names 1–60; date of birth age 16–120; gender `male|female|other`; nationality 2–56; address line1 1–120, city 1–60, country 2–56; national ID `^\d{2}-?\d{6,7}-?[A-Z]-?\d{2}$` (case-insensitive); passport `^[A-Z0-9]{6,12}$` + expiry in the future; documents: national ID needs `id_front` + `id_back`, passport needs `passport_bio`; proof of residence only when `/me` `outstanding` contains `documents.proof_of_residence`. Returns `Map<String,String>` with the same keys as the server.
- `KycFormViewModel(KycService, KycStatusController)`: `int step` (0 Personal, 1 Address, 2 Identification, 3 Documents, 4 Review); loads from `controller.status.draft`; field setters; autosave debounced 800 ms after the last edit and immediately on step change (`saveState: idle|saving|saved|error`); `next()` validates the current step (blocks with errors); `back()`; `upload(kind, file)` with progress and per-tile error + retry; `remove(documentId)`; `submit()` → on success refresh the controller and expose `submitted`; on `KycValidationException` map errors, jump to the first failing step.
- Phone is shown read-only from `status.phone` (never editable).
- Picking: camera or gallery via `image_picker` for photos; `file_picker` (`allowedExtensions: ['pdf','jpg','jpeg','png']`) for files. Client checks size ≤ 8 MB before upload.
- Copy (exact):
  - Title: "Verify your number"; step labels: "Personal", "Address", "ID details", "Documents", "Review".
  - Intro line on step 0: "POTRAZ requires us to confirm who owns each number. It takes about 5 minutes."
  - Save state: "Saving…", "Saved", "Not saved. Check your connection."
  - Document tiles: "National ID, front", "National ID, back", "Passport photo page", "Proof of residence"; empty: "Add photo or file"; uploading: "Uploading {n}%"; error: "Upload failed. Tap to retry."
  - Review step heading: "Check your details"; submit button: "Submit for review".
  - Success: "Thanks. We are reviewing your details. You can keep using the app while we check."
- Image previews from local bytes; uploaded server docs show a PDF icon or a thumbnail fetched via `fetchDocument`.

- [ ] **Step 1: Failing tests:** validation table (each rule, both ID types); view model autosave debounce (fake_async) and save-on-step-change; `next()` blocked with errors; upload progress, failure with retry, draft intact after failure; submit success refreshes controller; server field errors map and jump to the step; widget test: renders each step, keyboard types and labels present, no overflow at 375 × 800, 768 × 1024, 1280 × 800 (`tester.view.physicalSize`), submit button is the single primary button on review.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** PASS; analyze clean.
- [ ] **Step 5:** Commit `Add multi-step KYC form with autosave and uploads`.

### Task 5: Status page, notifications list and entry points

**Files:**
- Create: `lib/features/kyc/presentation/kyc_status_view.dart`, `lib/features/kyc/presentation/kyc_notifications_view.dart`, `lib/features/kyc/presentation/widgets/kyc_banner.dart`
- Modify: `lib/features/profile/presentation/views/profile_view.dart` (a "Verification" tile showing the status label), the home screen (`lib/features/home/presentation/views/home_view.dart` or its top widget) to show `KycBanner`
- Test: `test/features/kyc/kyc_status_view_test.dart`, `test/features/kyc/kyc_banner_test.dart`

**Interfaces:**
- Status labels (exact): NOT_STARTED "Not started", IN_PROGRESS "In progress", PENDING_REVIEW "Under review", APPROVED "Verified", REJECTED "Not approved", REQUIRES_CORRECTION "Needs a correction", EXPIRED "Expired", RESTRICTED "Action needed".
- `KycStatusView`: status label (the primary element), progress bar with percentage, deadline line ("Complete by {date}" when deadline set and not verified/pending), outstanding items as a checklist with human labels (map keys like `personal.firstName` → "First name", `documents.id_front` → "National ID, front"), reviewer note (show `rejectionReason` only when `underlyingStatus == REJECTED`, `correctionNotes` only when `REQUIRES_CORRECTION`), submission history list, primary button "Continue verification" (when `canEdit`) opening `KycFormView`; "Verification is not open yet." when `!launched`; "Updates" link to `KycNotificationsView`.
- `KycNotificationsView`: paginated list, unread dot (accent), mark read on open; empty "No updates yet."
- `KycBanner` on home: visible only when launched and status is not APPROVED/PENDING_REVIEW; one line + action: NOT_STARTED/IN_PROGRESS "Verify your number before {date}." [Continue]; REJECTED/REQUIRES_CORRECTION "Your KYC needs attention." [Review]; EXPIRED "Please renew your KYC." [Renew]; hairline border, no colour tile.

- [ ] **Step 1: Failing tests:** each status renders its label; reviewer note shown only for its matching status; not launched → "Verification is not open yet." and no button; outstanding labels mapped; banner hidden when approved/pending/not launched; banner text per status; notifications list empty/error/retry states; no overflow at the three widths.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement and wire entry points. **Step 4:** PASS; analyze clean.
- [ ] **Step 5:** Commit `Add KYC status page, updates list and entry points`.

### Task 6: Mandatory screen, gate and reminder sheet

**Files:**
- Create: `lib/features/kyc/presentation/kyc_gate.dart`, `lib/features/kyc/presentation/mandatory_kyc_view.dart`, `lib/features/kyc/presentation/widgets/kyc_reminder_sheet.dart`
- Modify: `lib/main.dart` (`MaterialApp.builder: (context, child) => KycGate(child: child!)`), the home screen (trigger the reminder sheet check after the first frame)
- Test: `test/features/kyc/kyc_gate_test.dart`, `test/features/kyc/kyc_reminder_sheet_test.dart`

**Interfaces:**
- `KycGate`: when `controller.launched && controller.isRestricted`, renders a full-screen nested `Navigator` (own key) starting at `MandatoryKycView` stacked over (and blocking) `child`; `PopScope(canPop: false)` at the root of that navigator, so back never reveals the app behind it; when restriction lifts (refresh after submit), the gate disappears and the app is usable again.
- `MandatoryKycView` copy (exact): heading "Complete your KYC verification"; body "Your account needs verification to keep using calls, shopping, payments and posts." and "POTRAZ requires us to confirm who owns each number. Emergency calls still work."; outstanding checklist (same labels as Task 5); progress; "About 5 minutes"; primary button "Complete KYC now" (pushes `KycFormView` inside the gate navigator); secondary text buttons "Contact support" (pushes the existing `HelpSupportView`) and "Sign out" (existing logout path). Not dismissible.
- `KycReminderSheet`: shown on home at most once per notification: picks the newest unread notification whose kind is `NUDGE_1`, `NUDGE_2`, `REMINDER` or any `REMINDER_<n>` (check `backend/kyc/job.js` / `notifications.js` for the stored kind and match both forms), `WARNING`, `CORRECTION_REQUESTED`, `REJECTED` or `EXPIRED`; remembers dismissed notification ids in SharedPreferences (`kyc_dismissed_notifications`, keep last 50); shows title/body, "Continue" (opens the form or status page) and "Later"; marks the notification read on either action; never shown when restricted (the gate covers that), not launched, approved or pending.

- [ ] **Step 1: Failing tests:** gate shows the mandatory view when restricted and hides child interaction; back does not pop; after submit + refresh with PENDING_REVIEW the gate disappears; "Contact support" opens help inside the gate; not launched → no gate; reminder sheet shows once for a new reminder, not again after "Later" (persisted), not when approved/restricted; layouts at the three widths without overflow.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement and wire. **Step 4:** PASS; analyze clean.
- [ ] **Step 5:** Commit `Add mandatory KYC screen, gate and reminder sheet`.

### Task 7: Visual check and end-to-end verification

**Files:**
- Create: `tool/kyc_preview/main.dart` (dev-only entry, not imported by the app: renders the KYC screens with a fake `KycService` in each state behind a simple state picker)
- Modify: none in app code unless the check finds a defect

- [ ] **Step 1:** `flutter analyze` on `lib/features/kyc`, `lib/core`, changed files — no new issues.
- [ ] **Step 2:** Targeted tests: `flutter test test/features/kyc test/features/call test/core` plus the broad pass from Global Constraints — only the 6 known `explore_tab_test.dart` failures.
- [ ] **Step 3:** `flutter run -d web-server --web-port 8099 -t tool/kyc_preview/main.dart` (or `flutter build web -t tool/kyc_preview/main.dart` and serve `build/web`). With Playwright, screenshot the form (each step), status page (NOT_STARTED, PENDING_REVIEW, REJECTED, APPROVED), mandatory screen and reminder sheet at 375, 768 and 1280 px wide, light and dark. Look at every screenshot for overflow, contrast, hierarchy and banned patterns. If the web build cannot compile, report why and fall back to widget-test layout checks only (state this clearly; do not claim visual verification).
- [ ] **Step 4:** Backend live check (scratchpad script, not committed): run the backend locally with in-memory Mongo, launch KYC, and point the preview's real-service mode at it for one pass: load status, save a draft, upload a PNG, submit, see Under review.
- [ ] **Step 5:** Commit `Add KYC preview entry for visual checks` (preview entry only; screenshots stay in the scratchpad).

---

Stage 3 (admin KYC page in `admin-panel/`) gets its own plan after this lands.
