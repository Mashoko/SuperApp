# Automatic Balance Refresh After Call Ends — Design Spec

Date: 2026-07-30
Status: Approved, pending implementation plan

## Context

This is the first of three independent calling-experience improvements
requested together (balance auto-refresh, a call-logs overhaul, and a
proximity-sensor feature) — each is a separate sub-project with its own
spec; this spec covers balance auto-refresh only.

Today, the account balance only updates when a user navigates to a screen
that triggers a fresh fetch (or manually pulls to refresh where supported).
After a call ends — regardless of outcome (completed, missed, declined, or
failed) — nothing re-fetches the balance, so a user can finish a call and
see a stale number until they happen to revisit a balance screen.

The app already has the pieces this feature needs, discovered while
scoping this spec:
- `SipCallManager` (`lib/core/managers/sip_call_manager.dart`) already
  listens to every SIP call-state transition and already distinguishes
  completed/missed/declined/failed outcomes in its `ENDED` and `FAILED`
  switch cases (used today for call-history logging).
- Balance is displayed from **two independent sources**: `AccountSummaryViewModel`
  (feeds Home's wallet card, the Account Summary screen, and Profile) and
  `DialpadViewModel` (feeds the Dialpad screen's own balance line). Both
  need refreshing after a call for "every balance widget" to stay in sync.
- Home's `MasterBalanceCard` already animates balance changes smoothly
  (`AnimatedSwitcher`, fade+slide, keyed on the balance value). The
  Dialpad screen's balance line is plain `Text` with no animation.
- **A real bug found during scoping:** both `AccountSummaryViewModel.fetchBalance()`
  and `DialpadViewModel.loadAccountInfo()` currently *clear* the balance
  (to `null`/`''`) when a fetch fails, rather than preserving the last
  known value. This directly contradicts "if the API request fails, keep
  the previous balance" — fixing it is a prerequisite for this feature,
  not optional polish.

## Goals

- Every balance-driven refresh (`fetchBalance()`, `loadAccountInfo()`) runs
  automatically within 1-2 seconds of a call ending, for every outcome:
  completed, missed, declined, or failed.
- Every balance-displaying screen (Home, Account Summary, Profile, Dialpad)
  reflects the new value without navigation, manual refresh, or app
  restart.
- A failed refresh preserves the previously-displayed balance and retries
  automatically (3 attempts: 2s, 5s, 10s backoff) before giving up
  silently.
- A subtle, one-time snackbar ("Unable to refresh balance. Retrying...")
  appears when retries begin — not repeated on every attempt.
- The Dialpad screen's balance line gains the same smooth-update animation
  Home's wallet card already has.

## Non-goals

- Consolidating `AccountSummaryViewModel` and `DialpadViewModel` into a
  single balance source. They stay separate; this feature refreshes both
  independently. (Worth revisiting later, but out of scope here — no
  unrelated refactor.)
- Any change to call-history/call-log recording, call-state granularity
  (rejected vs. cancelled vs. timed out), or the proximity sensor — each
  is a separate future sub-project.
- A persistent "balance may be stale" error indicator after all retries
  fail. Per the approved retry policy, giving up is silent; the next call
  or the next visit to a balance screen is the natural next chance to
  refresh.
- Indefinite/unbounded retry. Capped at 3 attempts (4 total tries
  including the first) per call-end event.

## Architecture

**Trigger:** `SipCallManager.callStateChanged`'s existing `CallStateEnum.ENDED`
and `CallStateEnum.FAILED` cases (`lib/core/managers/sip_call_manager.dart:44-51`)
already fire for every call-termination outcome in scope. A call to the new
coordinator (below) is added alongside the existing `_logCall(...)` calls in
both branches — no new call-state parsing needed.

**`BalanceRefreshCoordinator`** (new class, constructed once via `get_it`
alongside `SipCallManager` in `lib/core/di/inject.dart`, following the same
direct-reference pattern `SipCallManager` already uses for `DialpadViewModel`
rather than introducing an event bus): holds references to
`AccountSummaryViewModel` and `DialpadViewModel`. Its single public method,
`refreshAfterCall()`, is called from both `ENDED` and `FAILED`.

`refreshAfterCall()`:
1. If a refresh is already in flight, return immediately (guards against
   overlapping triggers — e.g., call-waiting scenarios ending two calls in
   quick succession).
2. Run `accountSummaryViewModel.fetchBalance()` and
   `dialpadViewModel.loadAccountInfo()` concurrently (`Future.wait`), each
   now returning a `bool` success flag (see ViewModel changes below).
3. If both succeed, done.
4. If either fails, show the "Unable to refresh balance. Retrying..."
   snackbar exactly once (via `navigatorKey.currentContext` — the same
   global key `SipCallManager` already uses to push `CallView`; no new
   global-messenger infrastructure needed), then retry only the failed
   fetch(es) after 2s, then 5s, then 10s.
5. After the final attempt, whether it succeeded or not, clear the
   in-flight flag and stop. On exhausted failure, nothing further happens —
   the last known values are already preserved (per the ViewModel fix), so
   the UI keeps showing the last good balance with no error state.

**ViewModel changes (prerequisite fix):**
- `AccountSummaryViewModel._fetchPaymentsBalance` (`lib/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart`):
  remove the `_paymentsBalance = null` assignment on failure — leave the
  field untouched. `fetchBalance()` returns `Future<bool>` (the `ok` flag)
  instead of `Future<void>`.
- `DialpadViewModel.loadAccountInfo()` (`lib/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart`):
  remove the `_accountBalance = ''` assignment on failure — leave the
  field untouched. Returns `Future<bool>` instead of `Future<void>`.
- Existing callers of these two methods (e.g., pull-to-refresh, initial
  load in `home_view.dart`'s `initState`) are unaffected — a `Future<bool>`
  is a valid drop-in for code that currently just awaits a `Future<void>`
  and ignores the result.

**Dialpad screen animation:** `lib/features/dialpad/presentation/views/dialpad_view.dart`'s
`Text("Balance: ...")` and `Text("Voice Bal: ...")` are each wrapped in an
`AnimatedSwitcher` (same fade+slide transition and duration as
`MasterBalanceCard`), keyed on the balance string, so updates animate
consistently across the app rather than just on Home.

## Data flow & error handling

- Normal path: call ends → `refreshAfterCall()` → both fetches succeed on
  the first attempt → `notifyListeners()` fires in each ViewModel → every
  `Consumer`/`Provider.of` reader rebuilds with the new value, animated by
  each screen's own `AnimatedSwitcher`.
- Failure path: one or both fetches fail → previous value stays displayed
  (untouched by the ViewModel fix) → snackbar shown once → retry with
  backoff → either recovers (silently, no further snackbar) or exhausts
  retries (silently gives up, last-good value remains on screen).
- Concurrency: the in-flight guard means a second call ending while a
  retry sequence is still running does not start a parallel sequence; it
  simply no-ops until the current sequence finishes, at which point the
  next natural trigger (or the app's existing periodic/manual refresh
  paths) catches up.
- Backgrounding: if the app is backgrounded mid-retry, the retry `Future`
  chain keeps running (it's not tied to widget lifecycle); state updates
  land whenever the relevant screen is next visible.

## Testing

- `BalanceRefreshCoordinator` unit tests with fake `AccountSummaryViewModel`/
  `DialpadViewModel` doubles: immediate success (no retry, no snackbar);
  fail-then-succeed on the second attempt (one snackbar, one retry, then
  success); all four attempts fail (one snackbar, silent give-up, no
  exception thrown); overlapping trigger while one sequence is in flight
  (second call is a no-op).
- `AccountSummaryViewModel`/`DialpadViewModel` tests added for the
  preserve-on-failure fix specifically (a fetch failure after a prior
  successful fetch must leave the displayed value unchanged) — this
  behavior is currently untested and, as found, currently wrong.
- Manual verification: end a call (completed, missed, declined, and
  failed) and confirm Home and Dialpad both update within ~1-2s with no
  navigation or manual refresh; temporarily point the payments/voice
  endpoints at an unreachable host to confirm the snackbar appears exactly
  once and the previous balance remains visible throughout the retry
  sequence.
