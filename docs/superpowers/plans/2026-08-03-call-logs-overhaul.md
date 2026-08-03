# Call Logs Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every call (incoming or outgoing) gets exactly one correct log entry with a proper status (completed/missed/declined/failed) and duration, written once when the call actually ends; both real navigation entry points into call history/stats read the same real data; the disconnected fake calling subsystem is deleted.

**Architecture:** A new `CallLogStatus` enum replaces `RecentCall`'s single `isMissed: bool`. A pure function (`resolveCallLogStatus`) maps primitives (isIncoming, didConnect, causeCode) to a status, mirroring the `resolveOnFetch` pattern from Balance Auto-Refresh — no `sip_ua` types, fully unit-testable. `SipCallManager` is fixed to log once, uniformly, for both call directions at their terminal state, using that function. `CallingView`'s Recents tab and the Dashboard's stats card are repointed from the dead `CallingService`/`CallingViewModel` onto the real `DialpadViewModel.recents` data everything else already uses. The fake subsystem is then deleted.

**Tech Stack:** Flutter 3.38.6 / Dart 3.10.7, `provider` (existing `ChangeNotifier` pattern), `shared_preferences` (existing JSON-string-list storage, unchanged), `flutter_test`.

## Global Constraints

- Logging timing (exact): both incoming and outgoing calls are logged exactly once, at `CallStateEnum.ENDED` or `CallStateEnum.FAILED` — never at `CALL_INITIATION`. The current pre-log-at-dial-start behavior for outgoing calls is removed entirely.
- Status mapping (exact, from the spec):

  | Scenario | Direction | Result |
  |---|---|---|
  | Call connects, then ends normally | either | `completed` |
  | Never connects; remote cancelled/timed out (487/408) | incoming | `missed` |
  | Never connects; we declined it | incoming | `declined` |
  | Never connects; far end didn't answer/rejected | outgoing | `declined` |
  | Never reaches a normal end at all (`FAILED` state) | either | `failed` |

- `RecentCall.isMissed` must remain available as a getter derived from `status == CallLogStatus.missed` — existing UI code (`call_history_widget.dart`, `call_history_view.dart`, `recents_view.dart` under `features/recents/`) reads it directly and must not be touched.
- Backward compatibility: `RecentCall.fromJson` must not throw on already-stored rows that have no `status` field (only the legacy `isMissed` bool) — fall back to `isMissed == true → missed`, `isMissed == false → completed`.
- Non-goal (do not do): consolidating `CallingView` and `DialpadView` into one screen. Both stay; only their data sources change.
- Non-goal (do not do): a "cancelled" status distinct from "declined" for an outgoing call the user hangs up while it's still ringing — deliberately folded into `declined`.
- Non-goal (do not do): any change to `CallView`, `CallViewModel`, or anything from the balance-auto-refresh or proximity-sensor plans.

---

### Task 1: `CallLogStatus` enum + `RecentCall` model update

**Files:**
- Create: `lib/features/recents/data/models/call_log_status.dart`
- Modify: `lib/features/recents/data/models/recent_call.dart`
- Test: `test/features/recents/recent_call_test.dart`

**Interfaces:**
- Produces: `enum CallLogStatus { completed, missed, declined, failed }` and `RecentCall` with a `status` field (replacing the stored `isMissed` bool) plus a derived `bool get isMissed => status == CallLogStatus.missed`. Task 2's pure function returns a `CallLogStatus`. Task 3 constructs `RecentCall(..., status: ...)`. Task 4 reads `call.status` for icon selection.

- [ ] **Step 1: Write the failing test**

Create `test/features/recents/recent_call_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/call_log_status.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/recent_call.dart';

void main() {
  group('RecentCall', () {
    test('isMissed is derived true when status is missed', () {
      final call = RecentCall(
        number: '1001',
        timestamp: DateTime(2026, 1, 1),
        status: CallLogStatus.missed,
      );
      expect(call.isMissed, isTrue);
    });

    test('isMissed is derived false for every other status', () {
      for (final status in [
        CallLogStatus.completed,
        CallLogStatus.declined,
        CallLogStatus.failed,
      ]) {
        final call = RecentCall(
          number: '1001',
          timestamp: DateTime(2026, 1, 1),
          status: status,
        );
        expect(call.isMissed, isFalse, reason: 'status was $status');
      }
    });

    test('toJson/fromJson round-trips status', () {
      final call = RecentCall(
        number: '1001',
        timestamp: DateTime(2026, 1, 1, 12, 30),
        status: CallLogStatus.declined,
        direction: 'incoming',
        durationSeconds: null,
      );

      final restored = RecentCall.fromJson(call.toJson());

      expect(restored.status, CallLogStatus.declined);
      expect(restored.number, '1001');
      expect(restored.direction, 'incoming');
    });

    test('fromJson falls back to deriving status from legacy isMissed=true when status is absent', () {
      final legacyJson = {
        'name': null,
        'number': '1002',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'isMissed': true,
        'direction': 'incoming',
        'durationSeconds': null,
      };

      final restored = RecentCall.fromJson(legacyJson);

      expect(restored.status, CallLogStatus.missed);
      expect(restored.isMissed, isTrue);
    });

    test('fromJson falls back to deriving status from legacy isMissed=false when status is absent', () {
      final legacyJson = {
        'name': null,
        'number': '1003',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'isMissed': false,
        'direction': 'outgoing',
        'durationSeconds': 42,
      };

      final restored = RecentCall.fromJson(legacyJson);

      expect(restored.status, CallLogStatus.completed);
      expect(restored.isMissed, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/recents/recent_call_test.dart`

Expected: FAIL — `call_log_status.dart` doesn't exist, and `RecentCall` has no `status` parameter yet.

- [ ] **Step 3: Create the status enum**

Create `lib/features/recents/data/models/call_log_status.dart`:

```dart
/// Final outcome of a logged call.
///
/// - [completed]: the call connected and ended normally, for either
///   direction.
/// - [missed]: an incoming call the remote party cancelled or that timed
///   out before we answered.
/// - [declined]: an incoming call we explicitly rejected, or an outgoing
///   call the far end didn't answer/rejected (including one we hung up
///   ourselves while it was still ringing — deliberately not split into a
///   separate "cancelled" status).
/// - [failed]: the call never reached a normal SIP termination at all
///   (network error, invalid destination, etc.), for either direction.
enum CallLogStatus { completed, missed, declined, failed }
```

- [ ] **Step 4: Update `RecentCall`**

Read the current file first: `lib/features/recents/data/models/recent_call.dart`. Replace its entire contents with:

```dart
import 'call_log_status.dart';

class RecentCall {
  final String? name;
  final String number;
  final DateTime timestamp;
  final CallLogStatus status;
  final String direction; // 'incoming' or 'outgoing'
  /// Call length in seconds when known (optional for older stored rows).
  final int? durationSeconds;

  RecentCall({
    this.name,
    required this.number,
    required this.timestamp,
    this.status = CallLogStatus.completed,
    this.direction = 'outgoing',
    this.durationSeconds,
  });

  /// Derived for backward compatibility with existing UI code that reads
  /// isMissed directly (call_history_widget.dart, recents_view.dart, etc.).
  bool get isMissed => status == CallLogStatus.missed;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'direction': direction,
      'durationSeconds': durationSeconds,
    };
  }

  factory RecentCall.fromJson(Map<String, dynamic> json) {
    return RecentCall(
      name: json['name'],
      number: json['number'],
      timestamp: DateTime.parse(json['timestamp']),
      status: _resolveStoredStatus(json),
      direction: json['direction'] ?? 'outgoing',
      durationSeconds: json['durationSeconds'] is int
          ? json['durationSeconds'] as int
          : (json['durationSeconds'] is num
              ? (json['durationSeconds'] as num).toInt()
              : null),
    );
  }

  /// Already-stored rows from before this field existed have no `status`
  /// key — only the legacy `isMissed` bool. Fall back to deriving a
  /// best-effort status from it so old rows keep displaying sensibly.
  static CallLogStatus _resolveStoredStatus(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    if (statusName != null) {
      return CallLogStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => CallLogStatus.completed,
      );
    }
    final legacyIsMissed = json['isMissed'] == true;
    return legacyIsMissed ? CallLogStatus.missed : CallLogStatus.completed;
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/recents/recent_call_test.dart`

Expected: `+5: All tests passed!`

- [ ] **Step 6: Check for compile errors elsewhere from the removed `isMissed` constructor parameter**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/`

`RecentCall`'s constructor no longer accepts `isMissed:` as a named parameter (it's now a derived getter). Check the analyze output for any call site still passing `isMissed:` to the constructor — if found, read that call site and fix it to pass the appropriate `status:` instead (there should be none today, since only `SipCallManager` constructs `RecentCall`, which Task 3 updates — but confirm here before moving on, since Task 1 lands before Task 3).

Expected: no new errors beyond what Task 3 will fix (Task 3 has not run yet, so `sip_call_manager.dart` is expected to show an error here about a removed/changed parameter — that's fine, it's Task 3's job; every other file should be clean).

- [ ] **Step 7: Commit**

```bash
git add lib/features/recents/data/models/call_log_status.dart lib/features/recents/data/models/recent_call.dart test/features/recents/recent_call_test.dart
git commit -m "feat(call-logs): add CallLogStatus enum and update RecentCall model"
```

---

### Task 2: `resolveCallLogStatus` pure function

**Files:**
- Create: `lib/core/utils/call_log_status_resolution.dart`
- Test: `test/core/utils/call_log_status_resolution_test.dart`

**Interfaces:**
- Consumes: `CallLogStatus` (from Task 1).
- Produces: `CallLogStatus resolveCallLogStatus({required bool isIncoming, required bool didConnect, required String causeCode})`. Task 3 depends on this exact signature.

- [ ] **Step 1: Write the failing tests**

Create `test/core/utils/call_log_status_resolution_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/utils/call_log_status_resolution.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/call_log_status.dart';

void main() {
  group('resolveCallLogStatus', () {
    test('connected call is completed, either direction', () {
      expect(
        resolveCallLogStatus(isIncoming: true, didConnect: true, causeCode: ''),
        CallLogStatus.completed,
      );
      expect(
        resolveCallLogStatus(isIncoming: false, didConnect: true, causeCode: ''),
        CallLogStatus.completed,
      );
    });

    test('incoming, never connected, remote cancelled (487) is missed', () {
      expect(
        resolveCallLogStatus(isIncoming: true, didConnect: false, causeCode: '487'),
        CallLogStatus.missed,
      );
    });

    test('incoming, never connected, timeout (408) is missed', () {
      expect(
        resolveCallLogStatus(isIncoming: true, didConnect: false, causeCode: '408'),
        CallLogStatus.missed,
      );
    });

    test('incoming, never connected, other cause is declined', () {
      expect(
        resolveCallLogStatus(isIncoming: true, didConnect: false, causeCode: '603'),
        CallLogStatus.declined,
      );
    });

    test('outgoing, never connected, is declined regardless of cause', () {
      expect(
        resolveCallLogStatus(isIncoming: false, didConnect: false, causeCode: '486'),
        CallLogStatus.declined,
      );
      expect(
        resolveCallLogStatus(isIncoming: false, didConnect: false, causeCode: ''),
        CallLogStatus.declined,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/core/utils/call_log_status_resolution_test.dart`

Expected: FAIL — `call_log_status_resolution.dart` does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/core/utils/call_log_status_resolution.dart`:

```dart
import '../../features/recents/data/models/call_log_status.dart';

/// Maps the outcome of a terminated call to a [CallLogStatus]. Pure and
/// side-effect-free — takes only primitives extracted from the real
/// `sip_ua` `Call`/`CallState` objects, so it's testable without faking
/// those types.
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

- [ ] **Step 4: Run test to verify it passes**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/core/utils/call_log_status_resolution_test.dart`

Expected: `+5: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/call_log_status_resolution.dart test/core/utils/call_log_status_resolution_test.dart
git commit -m "feat(call-logs): add pure resolveCallLogStatus helper"
```

---

### Task 3: Fix `SipCallManager` logging (uniform, once, at the end)

**Files:**
- Modify: `lib/core/managers/sip_call_manager.dart`

**Interfaces:**
- Consumes: `resolveCallLogStatus` (Task 2), `CallLogStatus` (Task 1), `RecentCall` (Task 1, now requires `status:` instead of `isMissed:`).
- Produces: no new public interface — this task only changes `SipCallManager`'s internal logging behavior. No other task depends on anything new here.

This task has no new automated test (matches this codebase's existing precedent: `SipCallManager` has no test file today, and nothing here changes that testability boundary — it's still driven by real `sip_ua` callback types). Correctness is covered by Task 2's tests (already proven) plus a manual verification pass in Task 7.

- [ ] **Step 1: Read the current file**

Read `lib/core/managers/sip_call_manager.dart` in full before editing — the exact current content is reproduced below for reference, but confirm it matches before applying changes (this file predates this plan and may have shifted).

Current content (as of this plan's authoring):

```dart
import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../features/call/presentation/views/call_view.dart';
import '../../features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import '../../features/recents/data/models/recent_call.dart';
import '../services/balance_refresh_coordinator.dart';

class SipCallManager implements SipUaHelperListener {
  final SIPUAHelper _sipHelper;
  final GlobalKey<NavigatorState> navigatorKey;
  final DialpadViewModel _dialpadViewModel;
  final BalanceRefreshCoordinator _balanceRefreshCoordinator;

  /// Tracks when each call was answered so we can compute accurate duration.
  final Map<String, DateTime> _connectedAt = {};

  SipCallManager(
    this._sipHelper,
    this.navigatorKey,
    this._dialpadViewModel,
    this._balanceRefreshCoordinator,
  ) {
    _sipHelper.addSipUaHelperListener(this);
  }

  void dispose() {
    _sipHelper.removeSipUaHelperListener(this);
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    final callId = call.id ?? call.remote_identity ?? '';

    switch (callState.state) {
      // ── Navigate to CallView on call initiation ────────────────────────────
      case CallStateEnum.CALL_INITIATION:
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => CallView(call: call)),
        );
        // Pre-log outgoing calls immediately so they show in recents.
        if (!call.direction.toString().toUpperCase().contains('INCOMING')) {
          _logCall(call, status: 'initiated', durationSeconds: null);
        }

      // ── Record the moment the call is answered ─────────────────────────────
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        _connectedAt[callId] = DateTime.now();

      // ── Log completed call on end ──────────────────────────────────────────
      case CallStateEnum.ENDED:
        _handleCallEnded(call, callState, callId);
        _balanceRefreshCoordinator.refreshAfterCall();

      case CallStateEnum.FAILED:
        _connectedAt.remove(callId);
        if (call.direction.toString().toUpperCase().contains('INCOMING')) {
          _logCall(call, status: 'failed', durationSeconds: null);
        }
        _balanceRefreshCoordinator.refreshAfterCall();

      default:
        break;
    }
  }

  void _handleCallEnded(Call call, CallState callState, String callId) {
    final connectedTime = _connectedAt.remove(callId);
    final isIncoming =
        call.direction.toString().toUpperCase().contains('INCOMING');

    if (!isIncoming) return; // Outgoing already logged at initiation.

    int? durationSeconds;
    String status;

    if (connectedTime != null) {
      durationSeconds =
          DateTime.now().difference(connectedTime).inSeconds;
      status = 'completed';
    } else {
      // Never connected — missed or declined.
      final cause = callState.cause?.cause ?? '';
      final callerCancelled = cause == '487' || cause == '408';
      status = callerCancelled ? 'missed' : 'declined';
    }

    _logCall(call, status: status, durationSeconds: durationSeconds);
  }

  Future<void> _logCall(
    Call call, {
    required String status,
    required int? durationSeconds,
  }) async {
    String number = call.remote_identity ?? 'Unknown';

    // Extract clean number from SIP URI  (e.g. "Name <sip:1001@domain>").
    final match = RegExp(r'sip:([^@>]+)').firstMatch(number);
    if (match != null) number = match.group(1)!;

    final isIncoming =
        call.direction.toString().toUpperCase().contains('INCOMING');

    await _dialpadViewModel.addRecentCall(RecentCall(
      number: number,
      timestamp: DateTime.now(),
      isMissed: status == 'missed',
      direction: isIncoming ? 'incoming' : 'outgoing',
      durationSeconds: durationSeconds,
    ));
  }

  // ── Unused overrides ───────────────────────────────────────────────────────

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void registrationStateChanged(RegistrationState state) {}
  @override
  void transportStateChanged(TransportState state) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
```

- [ ] **Step 2: Apply the fix**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../features/call/presentation/views/call_view.dart';
import '../../features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import '../../features/recents/data/models/call_log_status.dart';
import '../../features/recents/data/models/recent_call.dart';
import '../services/balance_refresh_coordinator.dart';
import '../utils/call_log_status_resolution.dart';

class SipCallManager implements SipUaHelperListener {
  final SIPUAHelper _sipHelper;
  final GlobalKey<NavigatorState> navigatorKey;
  final DialpadViewModel _dialpadViewModel;
  final BalanceRefreshCoordinator _balanceRefreshCoordinator;

  /// Tracks when each call was answered so we can compute accurate duration.
  final Map<String, DateTime> _connectedAt = {};

  SipCallManager(
    this._sipHelper,
    this.navigatorKey,
    this._dialpadViewModel,
    this._balanceRefreshCoordinator,
  ) {
    _sipHelper.addSipUaHelperListener(this);
  }

  void dispose() {
    _sipHelper.removeSipUaHelperListener(this);
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    final callId = call.id ?? call.remote_identity ?? '';

    switch (callState.state) {
      // ── Navigate to CallView on call initiation ────────────────────────────
      case CallStateEnum.CALL_INITIATION:
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => CallView(call: call)),
        );

      // ── Record the moment the call is answered ─────────────────────────────
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        _connectedAt[callId] = DateTime.now();

      // ── Log the call, either direction, exactly once, on end ───────────────
      case CallStateEnum.ENDED:
        _handleCallEnded(call, callState, callId);
        _balanceRefreshCoordinator.refreshAfterCall();

      // ── Log the call, either direction, exactly once, on failure ───────────
      case CallStateEnum.FAILED:
        _connectedAt.remove(callId);
        _logCall(
          call,
          status: CallLogStatus.failed,
          durationSeconds: null,
        );
        _balanceRefreshCoordinator.refreshAfterCall();

      default:
        break;
    }
  }

  void _handleCallEnded(Call call, CallState callState, String callId) {
    final connectedTime = _connectedAt.remove(callId);
    final isIncoming =
        call.direction.toString().toUpperCase().contains('INCOMING');

    int? durationSeconds;
    final didConnect = connectedTime != null;

    if (didConnect) {
      durationSeconds = DateTime.now().difference(connectedTime).inSeconds;
    }

    final status = resolveCallLogStatus(
      isIncoming: isIncoming,
      didConnect: didConnect,
      causeCode: callState.cause?.cause ?? '',
    );

    _logCall(call, status: status, durationSeconds: durationSeconds);
  }

  Future<void> _logCall(
    Call call, {
    required CallLogStatus status,
    required int? durationSeconds,
  }) async {
    String number = call.remote_identity ?? 'Unknown';

    // Extract clean number from SIP URI  (e.g. "Name <sip:1001@domain>").
    final match = RegExp(r'sip:([^@>]+)').firstMatch(number);
    if (match != null) number = match.group(1)!;

    final isIncoming =
        call.direction.toString().toUpperCase().contains('INCOMING');

    await _dialpadViewModel.addRecentCall(RecentCall(
      number: number,
      timestamp: DateTime.now(),
      status: status,
      direction: isIncoming ? 'incoming' : 'outgoing',
      durationSeconds: durationSeconds,
    ));
  }

  // ── Unused overrides ───────────────────────────────────────────────────────

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void registrationStateChanged(RegistrationState state) {}
  @override
  void transportStateChanged(TransportState state) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
```

Note what changed: the `CALL_INITIATION` pre-log call is gone entirely; `FAILED` now logs unconditionally (both directions) with `status: CallLogStatus.failed`; `_handleCallEnded` no longer has the `if (!isIncoming) return;` early exit, and computes `status` via `resolveCallLogStatus` for both directions instead of hand-rolling incoming-only logic; `_logCall`'s `status` parameter is now `CallLogStatus` instead of `String`, and it passes `status: status` to `RecentCall` instead of `isMissed: status == 'missed'`.

- [ ] **Step 3: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/core/managers/sip_call_manager.dart`

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/core/managers/sip_call_manager.dart
git commit -m "fix(call-logs): log every call once, uniformly, at its terminal state"
```

---

### Task 4: Repoint `CallingView`'s Recents tab to real data

**Files:**
- Modify: `lib/features/calling/presentation/views/tabs/recents_view.dart`
- Modify: `lib/features/calling/presentation/views/calling_view.dart`

**Interfaces:**
- Consumes: `DialpadViewModel.recents` (existing, unchanged), `CallLogStatus` (Task 1), `CallViewModel.makeCall` (existing, unchanged), `getIt` (existing DI locator).
- Produces: nothing new — this is a leaf UI fix. No other task depends on it.

This task has no new automated test (no existing widget-test harness for either file, matching their current untested state — the same precedent already established for `CallView` in the proximity-sensor plan). Verification is `dart analyze` plus manual confirmation in Task 7.

- [ ] **Step 1: Replace `tabs/recents_view.dart`**

Read the current file first: `lib/features/calling/presentation/views/tabs/recents_view.dart`. Replace its entire contents with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/call/presentation/viewmodels/call_viewmodel.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/call_log_status.dart';

class RecentsView extends StatelessWidget {
  const RecentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DialpadViewModel>(
      builder: (context, viewModel, child) {
        final recents = viewModel.recents;

        if (recents.isEmpty) {
          return const Center(
            child: Text('No recent calls'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: recents.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final call = recents[index];
            final visuals = _visualsFor(call.status);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: visuals.tint.withValues(alpha: 0.12),
                child: Icon(visuals.icon, color: visuals.tint),
              ),
              title: Text(
                call.name ?? call.number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: call.isMissed ? Colors.red : Colors.black,
                ),
              ),
              subtitle: Text(
                DateFormat('MMM d, h:mm a').format(call.timestamp),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Color(0xFF00897B)),
                onPressed: () async {
                  final callViewModel =
                      Provider.of<CallViewModel>(context, listen: false);
                  final error = await callViewModel.makeCall(
                    call.number,
                    voiceOnly: true,
                  );
                  if (!context.mounted || error == null) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

({IconData icon, Color tint}) _visualsFor(CallLogStatus status) {
  switch (status) {
    case CallLogStatus.missed:
      return (icon: Icons.call_missed, tint: Colors.red);
    case CallLogStatus.declined:
      return (icon: Icons.call_missed_outgoing, tint: Colors.orange);
    case CallLogStatus.failed:
      return (icon: Icons.error_outline, tint: Colors.red);
    case CallLogStatus.completed:
      return (icon: Icons.call_made, tint: const Color(0xFF00897B));
  }
}
```

- [ ] **Step 2: Fix `calling_view.dart`'s data loading**

In `lib/features/calling/presentation/views/calling_view.dart`, add these imports alongside the existing ones:

```dart
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
```

Remove the now-unused import (the `CallingViewModel` is deleted in Task 6, but this file's only remaining reference to it is the line below, which is being replaced now):

```dart
import 'package:mvvm_sip_demo/features/calling/presentation/viewmodels/calling_viewmodel.dart';
```

Find the `_loadData` method:

```dart
  void _loadData() {
    final viewModel = Provider.of<CallingViewModel>(context, listen: false);
    viewModel.loadActiveCalls();
    viewModel.loadCallHistory();
  }
```

Replace it with:

```dart
  void _loadData() {
    getIt<DialpadViewModel>().loadRecents();
  }
```

- [ ] **Step 3: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/features/calling`

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/calling/presentation/views/tabs/recents_view.dart lib/features/calling/presentation/views/calling_view.dart
git commit -m "fix(call-logs): repoint CallingView's Recents tab to real call data"
```

---

### Task 5: Fix Dashboard call stats to use real data

**Files:**
- Modify: `lib/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart`
- Test: `test/features/dashboard/dashboard_call_stats_test.dart`

**Interfaces:**
- Consumes: `DialpadViewModel.recents` (existing), `RecentCall`/`CallLogStatus` (Task 1).
- Produces: `DashboardViewModel`'s constructor now takes a `DialpadViewModel` in place of `CallingService` (same position). No other task depends on this.

- [ ] **Step 1: Write the failing test**

Create `test/features/dashboard/dashboard_call_stats_test.dart` — this tests the aggregation logic directly against a list of `RecentCall`s (the same shape `DialpadViewModel.recents` returns), without needing to construct a full `DashboardViewModel` or its other two service dependencies:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/call_log_status.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/recent_call.dart';

void main() {
  group('DashboardViewModel.callStatsFrom', () {
    test('counts total calls, missed calls, and sums durations', () {
      final recents = [
        RecentCall(
          number: '1',
          timestamp: DateTime(2026, 1, 1),
          status: CallLogStatus.completed,
          durationSeconds: 60,
        ),
        RecentCall(
          number: '2',
          timestamp: DateTime(2026, 1, 2),
          status: CallLogStatus.missed,
          durationSeconds: null,
        ),
        RecentCall(
          number: '3',
          timestamp: DateTime(2026, 1, 3),
          status: CallLogStatus.declined,
          durationSeconds: null,
        ),
        RecentCall(
          number: '4',
          timestamp: DateTime(2026, 1, 4),
          status: CallLogStatus.completed,
          durationSeconds: 30,
        ),
      ];

      final stats = DashboardViewModel.callStatsFrom(recents);

      expect(stats['total_calls'], 4);
      expect(stats['missed_calls'], 1);
      expect(stats['total_duration_seconds'], 90);
    });

    test('handles an empty list', () {
      final stats = DashboardViewModel.callStatsFrom(const []);

      expect(stats['total_calls'], 0);
      expect(stats['missed_calls'], 0);
      expect(stats['total_duration_seconds'], 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/dashboard/dashboard_call_stats_test.dart`

Expected: FAIL — `DashboardViewModel.callStatsFrom` does not exist yet.

- [ ] **Step 3: Update `DashboardViewModel`**

Read the current file first: `lib/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart`. Replace its entire contents with:

```dart
import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/recent_call.dart';
import 'package:mvvm_sip_demo/services/shopping_service.dart';
import 'package:mvvm_sip_demo/services/utility_bills_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final DialpadViewModel _dialpadViewModel;
  final ShoppingService _shoppingService;
  final UtilityBillsService _utilityBillsService;

  DashboardViewModel(
    this._dialpadViewModel,
    this._shoppingService,
    this._utilityBillsService,
  );

  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> get dashboardData => _dashboardData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Aggregates real call-log entries into the same shape the dashboard
  /// card renders. Static and pure so it's testable without constructing
  /// a full DashboardViewModel or its other service dependencies.
  static Map<String, dynamic> callStatsFrom(List<RecentCall> recents) {
    final totalDuration = recents.fold<int>(
      0,
      (sum, call) => sum + (call.durationSeconds ?? 0),
    );
    final missedCalls = recents.where((call) => call.isMissed).length;

    return {
      'total_calls': recents.length,
      'missed_calls': missedCalls,
      'total_duration_seconds': totalDuration,
    };
  }

  Future<void> loadDashboard(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      // Get calling stats from real call history.
      await _dialpadViewModel.loadRecents();
      final callStats = callStatsFrom(_dialpadViewModel.recents);

      // Get shopping info
      final cart = await _shoppingService.fetchCart(userId);
      final orders = await _shoppingService.fetchOrders(userId);

      // Get payments info
      final payments = _utilityBillsService.getPayments(userId);
      final totalSpent = payments.fold(0.0, (sum, p) => sum + p.amount);
      final lastPayment = payments.isNotEmpty ? payments.first : null;

      _dashboardData = {
        'user_id': userId,
        'calling': callStats,
        'shopping': {
          'cart_items': cart['item_count'],
          'cart_total': cart['total'],
          'total_orders': orders.length,
        },
        'payments': {
          'total_spent': totalSpent,
          'total_payments': payments.length,
          'last_payment_amount': lastPayment?.amount ?? 0.0,
        },
      };

      notifyListeners();
    } catch (e) {
      _setError('Failed to load dashboard: $e');
    } finally {
      _setLoading(false);
    }
  }
}
```

Note: `dashboard_view.dart` reads `data['calling']['total_calls']`,
`data['calling']['missed_calls']`, and
`data['calling']['total_duration_seconds']` — all three keys are preserved
exactly by `callStatsFrom`, so no changes are needed there.

- [ ] **Step 4: Run test to verify it passes**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/dashboard/dashboard_call_stats_test.dart`

Expected: `+2: All tests passed!`

- [ ] **Step 5: Update the DI registration**

In `lib/core/di/inject.dart`, find:

```dart
  getIt.registerFactory(() => DashboardViewModel(getIt(), getIt(), getIt()));
```

Replace with:

```dart
  getIt.registerFactory(() => DashboardViewModel(
      getIt<DialpadViewModel>(), getIt(), getIt()));
```

(`DialpadViewModel` is already imported in this file from earlier plans — confirm the import exists; if not, add
`import '../../features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';`
alongside the other feature imports.)

- [ ] **Step 6: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/features/dashboard lib/core/di/inject.dart`

Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart lib/core/di/inject.dart test/features/dashboard/dashboard_call_stats_test.dart
git commit -m "fix(call-logs): compute Dashboard call stats from real call history"
```

---

### Task 6: Delete the fake calling subsystem

**Files:**
- Delete: `lib/services/calling_service.dart`
- Delete: `lib/features/calling/presentation/viewmodels/calling_viewmodel.dart`
- Delete: `lib/models/calling/call.dart`
- Delete: `lib/models/calling/call_status.dart`
- Modify: `lib/core/di/inject.dart`
- Modify: `lib/main.dart`

**Interfaces:** None — this task only removes dead code that Tasks 4-5 already stopped depending on.

This task has no new test — it's pure deletion, verified by `dart analyze` finding zero remaining references.

- [ ] **Step 1: Confirm nothing still references the fake subsystem**

Run: `grep -rn "CallingService\|CallingViewModel\|models/calling" lib --include="*.dart"`

Expected output (before deleting anything): only the files being deleted in this task, plus their two references in `inject.dart` and `main.dart` handled in the steps below. If anything else shows up, stop and investigate — it means Task 4 or 5 missed a reference; do not proceed with deletion until the grep is limited to exactly what this task removes.

- [ ] **Step 2: Delete the four files**

```bash
git rm lib/services/calling_service.dart
git rm lib/features/calling/presentation/viewmodels/calling_viewmodel.dart
git rm lib/models/calling/call.dart
git rm lib/models/calling/call_status.dart
```

If `lib/models/calling/` is now empty, it will be removed automatically by git (empty directories aren't tracked).

- [ ] **Step 3: Remove the DI registrations**

In `lib/core/di/inject.dart`, remove these two import lines:

```dart
import '../../services/calling_service.dart';
```
```dart
import '../../features/calling/presentation/viewmodels/calling_viewmodel.dart';
```

And remove these two registration lines:

```dart
  getIt.registerLazySingleton<CallingService>(() => CallingService());
```
```dart
  getIt.registerFactory(() => CallingViewModel(getIt()));
```

- [ ] **Step 4: Remove the provider registration**

In `lib/main.dart`, remove this import:

```dart
import 'features/calling/presentation/viewmodels/calling_viewmodel.dart';
```

And remove this line from the `MultiProvider`'s `providers` list:

```dart
        ChangeNotifierProvider(create: (_) => getIt<CallingViewModel>()),
```

- [ ] **Step 5: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze`

Expected: only the pre-existing, unrelated issues already known from prior work in this repo (an unused import in `otp_auth_service.dart` and a handful of `withOpacity`/`BuildContext`-across-async-gap infos elsewhere) — zero new issues, and specifically zero "undefined name"/"target of URI doesn't exist" errors related to the deleted files.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(call-logs): delete the disconnected fake calling subsystem"
```

---

### Task 7: Final verification pass

**Files:** None (verification only).

- [ ] **Step 1: Full project analyze**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze`

Expected: only the pre-existing, unrelated issues already known from prior work in this repo — zero new issues introduced by this plan.

- [ ] **Step 2: Run the focused test suite for this feature**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/recents/recent_call_test.dart test/core/utils/call_log_status_resolution_test.dart test/features/dashboard/dashboard_call_stats_test.dart`

Expected: `+12: All tests passed!` (5 + 5 + 2).

- [ ] **Step 3: Confirm no other test file references anything this plan deleted or restructured**

Run: `grep -rl "CallingViewModel\|CallingService\|models/calling\|RecentCall(" test/ 2>/dev/null`

Expected: only the three new test files this plan created (which correctly use `RecentCall(...)` with the new `status:` parameter). If any other file appears, read it and confirm it still passes before proceeding.

- [ ] **Step 4: Note the manual verification that remains**

Record in the task report (not a new file) that a real-device pass is still needed and is environment-blocked here, matching the same precedent already established for the balance-auto-refresh and proximity-sensor plans: make an outgoing call that completes and confirm it shows the correct duration in `DialpadView`'s Recents tab, `CallingView`'s Recents tab, `CallHistoryView`, and Home's "Recent activity" card, all showing the same entry; let an outgoing call ring unanswered and confirm it logs as `declined`; receive and miss a call and confirm `missed`; receive and decline a call and confirm `declined`; force a connection failure (e.g. airplane mode mid-dial) and confirm `failed`; check the Dashboard stats card reflects real counts.
