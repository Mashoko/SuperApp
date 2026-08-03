# Call Logs Overhaul — Design Spec

Date: 2026-08-03
Status: Approved, pending implementation plan

## Context

This is the second of three independent calling-experience improvements
requested together (balance auto-refresh, this call-logs overhaul, and a
proximity-sensor feature) — each is a separate sub-project with its own
spec; this spec covers call logs only. Balance auto-refresh and the
proximity sensor feature both already shipped
(`docs/superpowers/specs/2026-07-30-balance-auto-refresh-design.md`,
`docs/superpowers/specs/2026-08-03-proximity-sensor-design.md`).

A full audit of the call-log code (not guesswork) found the situation is
more serious than typical polish — several real, concrete bugs:

1. **Two disconnected call-history systems.** The app has two parallel
   "calling hub" screens with near-identical tab structures:
   - `DialpadView` (`lib/features/dialpad/presentation/views/dialpad_view.dart`)
     — shown as a bottom sheet from Home's primary dialer button
     (`home_view.dart`'s `_openDialpadSheet`, wired to `onDialerTap`) — the
     everyday entry point. Its Recents tab
     (`lib/features/recents/presentation/views/recents_view.dart`) correctly
     shows real data via `DialpadViewModel.recents`.
   - `CallingView` (`lib/features/calling/presentation/views/calling_view.dart`)
     — a full-screen screen with the same tab structure (Dialer/Recents/
     Contacts/Speed Test), reachable from Home's "Calling" services tile,
     the Dashboard's call button, and one empty-state link. Its Dialer tab
     was updated to use the real `CallViewModel.makeCall` (so calls placed
     from here work correctly), but its Recents tab
     (`lib/features/calling/presentation/views/tabs/recents_view.dart`)
     still reads `CallingViewModel.callHistory` — backed by
     `CallingService`, an in-memory-only mock whose `initiateCall`/
     `answerCall`/`rejectCall`/`endCall` methods are **never called
     anywhere in the app** for real calls (verified via
     project-wide grep). This tab shows empty/fake data regardless of
     actual call activity.
   - `DashboardViewModel` also reads `CallingService.getCallStatistics(userId)`
     for its "total calls / missed calls / total duration" stats card — same
     dead data source, so this card is always effectively zero.
   - This appears to be a genuine leftover: `CallingView` was likely an
     earlier iteration of the calling UI, superseded by `DialpadView`, but
     never fully retired — its data layer was never repointed.
2. **Outgoing calls are logged once and never updated.**
   `SipCallManager` (`lib/core/managers/sip_call_manager.dart`) pre-logs
   outgoing calls the instant dialing starts
   (`CallStateEnum.CALL_INITIATION`, status `'initiated'`), then explicitly
   skips updating them when the call ends
   (`_handleCallEnded`'s `if (!isIncoming) return;`). There is no
   update/upsert path in storage — `DialpadRepositoryImpl.addRecent` only
   ever inserts new rows. Every outgoing call permanently shows
   `"initiated"` with `durationSeconds: null`, regardless of whether it
   connected for 10 minutes or was instantly rejected.
3. **Outgoing failures are silently dropped.** The `FAILED` case in
   `SipCallManager.callStateChanged` only logs when the call is incoming
   (`if (call.direction...contains('INCOMING'))`).
4. **Lossy status model.** `RecentCall`
   (`lib/features/recents/data/models/recent_call.dart`) only has
   `isMissed: bool` — no way to represent "declined by me" vs "failed" vs
   "completed" distinctly.

No backend/server-side call-log storage exists anywhere in this app
(verified: no matches in `backend/`) — call logs are entirely on-device,
stored as JSON strings in a SharedPreferences string list capped at 50
entries (`DialpadLocalDataSourceImpl`/`DialpadRepositoryImpl`). No sync
concerns.

## Goals

- Every call gets exactly one log entry, written once when the call
  actually ends, with the correct final status and duration — for both
  incoming and outgoing calls alike.
- A proper `CallLogStatus` (completed / missed / declined / failed)
  replaces the single `isMissed: bool`, while keeping `isMissed` available
  as a derived getter for backward compatibility with existing UI code.
- `CallingView`'s Recents tab and the Dashboard's call-stats card both read
  from the same real data `DialpadView`'s Recents tab and `CallHistoryView`
  already use.
- The now-fully-unused fake calling subsystem (`CallingService`,
  `CallingViewModel`, `lib/models/calling/call.dart`,
  `lib/models/calling/call_status.dart`) is deleted.
- Already-stored call-log entries (old JSON format, no `status` field)
  continue to display sensibly rather than crashing or defaulting oddly.

## Non-goals

- Consolidating `CallingView` and `DialpadView` into a single hub screen.
  Both screens keep existing side by side; only their data sources are
  fixed. Worth revisiting later as its own navigation/UX project.
- A dedicated "cancelled" status for an outgoing call the user hangs up
  themselves while it's still ringing. This is deliberately folded into
  `declined` as an acceptable simplification (see the status-mapping table
  below) rather than adding a fifth status.
- Any change to `CallView`, `CallViewModel`, or anything from the
  balance-auto-refresh or proximity-sensor plans.
- Migrating storage off SharedPreferences, or adding a proper upsert/update
  path — the "log once, at the end" design (see Architecture) makes both
  unnecessary.

## Architecture

**Trigger timing:** the pre-log-at-dial-start behavior is removed
entirely. Both incoming and outgoing calls are logged exactly once, at
their terminal `sip_ua` state (`CallStateEnum.ENDED` or
`CallStateEnum.FAILED`), matching how incoming calls already work today.
This trades away the current "shows up immediately while still dialing"
behavior in exchange for guaranteeing every entry is correct — a
deliberate, approved simplification over adding a stable call ID and an
update-in-place storage path.

**`resolveCallLogStatus`** (new, pure function,
`lib/core/utils/call_log_status_resolution.dart`):
```dart
CallLogStatus resolveCallLogStatus({
  required bool isIncoming,
  required bool didConnect,
  required String causeCode,
}) {
  if (didConnect) return CallLogStatus.completed;
  if (isIncoming) {
    // 487 = caller cancelled (Request Terminated), 408 = timeout — remote
    // party gave up before we answered.
    final callerCancelled = causeCode == '487' || causeCode == '408';
    return callerCancelled ? CallLogStatus.missed : CallLogStatus.declined;
  }
  // Outgoing, never connected: the far end didn't pick up / rejected.
  return CallLogStatus.declined;
}
```
Takes only primitives — no `sip_ua` import — so it's testable without any
fakes, mirroring the `resolveOnFetch` precedent from the balance
auto-refresh plan. `SipCallManager` extracts the primitives from the real
`Call`/`CallState` objects and calls this function; it stays a thin
orchestrator rather than owning the status-mapping rules itself.

**Status mapping table:**

| Scenario | Direction | Result |
|---|---|---|
| Call connects, then ends normally | either | `completed` |
| Never connects; remote cancelled/timed out (487/408) | incoming | `missed` |
| Never connects; we declined it | incoming | `declined` |
| Never connects; far end didn't answer/rejected | outgoing | `declined` |
| Never reaches a normal end at all (network error, bad destination) | either | `failed` |

**`SipCallManager`** (`lib/core/managers/sip_call_manager.dart`) changes:
- Remove the `CALL_INITIATION` case's pre-log call entirely.
- `ENDED` case: call `_logCall` for both directions (remove the
  `if (!isIncoming) return;` early exit in `_handleCallEnded`), using
  `resolveCallLogStatus` with `didConnect` derived from whether
  `_connectedAt` had an entry for this call.
- `FAILED` case: call `_logCall` for both directions (remove the
  incoming-only guard), with `didConnect: false` — this resolves to
  `CallLogStatus.failed` since a `FAILED` state (as opposed to a normal
  `ENDED` with a decline cause) means the call never reached a proper SIP
  termination at all.
- `_logCall`'s `status` parameter changes from `String` to `CallLogStatus`.

## Data Model Changes

**`CallLogStatus`** (new, `lib/features/recents/data/models/call_log_status.dart`):
```dart
enum CallLogStatus { completed, missed, declined, failed }
```

**`RecentCall`** (`lib/features/recents/data/models/recent_call.dart`) gains
a `status` field, replacing `isMissed` as the source of truth:
```dart
class RecentCall {
  final String? name;
  final String number;
  final DateTime timestamp;
  final CallLogStatus status;
  final String direction; // 'incoming' or 'outgoing'
  final int? durationSeconds;

  /// Derived for backward compatibility with existing UI code that reads
  /// isMissed directly.
  bool get isMissed => status == CallLogStatus.missed;
}
```
`toJson` serializes `status` via `status.name`. `fromJson` reads `status`
by name when present; when absent (an already-stored, pre-overhaul row),
it falls back to deriving a best-effort status from the legacy `isMissed`
field (`true → missed`, `false → completed`) so old rows keep displaying
sensibly.

## Retiring the Fake Subsystem

- **Delete:** `lib/services/calling_service.dart`,
  `lib/features/calling/presentation/viewmodels/calling_viewmodel.dart`,
  `lib/models/calling/call.dart`, `lib/models/calling/call_status.dart`, and
  their DI registrations (`inject.dart`) and the `ChangeNotifierProvider`
  in `main.dart`.
- **`lib/features/calling/presentation/views/tabs/recents_view.dart`**
  (the `CallingView` Recents tab): repointed from
  `Consumer<CallingViewModel>` reading `viewModel.callHistory` to
  `Consumer<DialpadViewModel>` reading `viewModel.recents` — the same
  `RecentCall`/`CallLogStatus` data `DialpadView`'s Recents tab and
  `CallHistoryView` already use. Icon/label logic reads `status` instead of
  the old ad hoc string check. A tap-to-call-back action is added
  (currently this tile has none), matching the existing pattern in
  `CallHistoryView`/`call_history_widget.dart`.
- **`calling_view.dart`**: `_loadData()` no longer calls the deleted
  `CallingViewModel` loader methods; instead calls
  `getIt<DialpadViewModel>().loadRecents()`, matching
  `CallHistoryView.initState`'s existing pattern.
- **`DashboardViewModel`**
  (`lib/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart`):
  constructor drops its `CallingService` dependency; the `'calling'` stats
  block (`total_calls`, `missed_calls`, `total_duration_seconds`) is
  computed by aggregating `DialpadViewModel.recents` directly instead of
  calling the deleted service.

## Testing

- `resolveCallLogStatus` — pure function, unit-tested against every row of
  the status-mapping table above (5 cases), no fakes needed.
- `RecentCall.fromJson` — a fully-modern JSON blob (has `status`); a legacy
  blob with only `isMissed` and no `status` field (backward-compat
  fallback); confirms `isMissed` is correctly derived from `status` in
  both directions.
- Dashboard stats aggregation — given a list of `RecentCall`s with known
  statuses/durations, the computed `total_calls`/`missed_calls`/
  `total_duration_seconds` match by hand-calculation.
- No new automated test for `SipCallManager` itself (matches this
  codebase's existing precedent — it has no test file today, and nothing
  here changes that testability boundary; it's still driven by real
  `sip_ua` callback types). Correctness is covered by the pure-function
  tests above plus a manual verification pass.
- Manual verification (real device, same "environment-blocked here"
  precedent as the balance auto-refresh and proximity-sensor plans): an
  outgoing call that completes appears with correct duration in
  `DialpadView`'s Recents tab, `CallingView`'s Recents tab,
  `CallHistoryView`, and Home's "Recent activity" card, all showing the
  same entry; an outgoing call left ringing unanswered logs as `declined`;
  a missed incoming call logs as `missed`; a declined incoming call logs as
  `declined`; a forced connection failure (e.g. airplane mode mid-dial)
  logs as `failed`; the Dashboard stats card reflects real counts.
