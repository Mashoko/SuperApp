# Balance Auto-Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically refresh every balance-displaying screen within 1-2 seconds of any call ending (completed, missed, declined, or failed), with retry-with-backoff on failure and no loss of the last-known balance.

**Architecture:** A new pure helper (`resolveOnFetch`) fixes an existing bug where failed balance fetches wipe the displayed value instead of preserving it. A new `BalanceRefreshCoordinator` — a plain Dart class with no Flutter/network dependencies of its own, driven entirely by injected callback functions — owns the retry/coalescing/notify logic and is triggered from `SipCallManager`'s existing call-state listener.

**Tech Stack:** Flutter, `provider` (ChangeNotifier view models), `get_it` (DI), `fake_async` (dev-only, for testing the retry timing without real delays).

## Global Constraints

- Retry policy: 3 retries after the initial attempt (2s, 5s, 10s backoff) — 4 total attempts per call-end event. Silent give-up after that; no persistent error state.
- Exact snackbar copy: `"Unable to refresh balance. Retrying..."`, shown exactly once per refresh sequence (not per attempt).
- A failed fetch must never clear an already-displayed balance — the previous value is always preserved.
- No new global-messenger key — reuse the existing `navigatorKey` (`lib/main.dart`) for showing the snackbar.
- **Discovered during planning, in scope for this plan:** `AccountSummaryViewModel` is currently registered in `lib/core/di/inject.dart` as `getIt.registerFactory(...)`, meaning every `getIt<AccountSummaryViewModel>()` call constructs a brand-new instance. Two call sites already exist (`lib/main.dart`'s `MultiProvider` and `lib/features/account_summary/presentation/views/account_summary_view.dart`'s `initState`), so the app already has at least two independent, un-synchronized instances today. This directly blocks the spec's "every balance widget stays synchronized" goal and must be fixed (factory → lazy singleton) for the new coordinator to refresh the same instance the UI actually watches. Verified safe: `account_summary_view.dart` already calls `loadCurrentUser()` on whatever instance it gets, which is idempotent and safe to call on an already-loaded singleton.
- Run `dart analyze` (scoped to files touched by a task) after every task. Do not run the full `flutter test` suite or `flutter build` in a task's own verification — the user has asked to avoid slow full-suite/build foreground and background commands this session; use the focused test commands each task specifies.

---

### Task 1: Pure `resolveOnFetch` helper

**Files:**
- Create: `lib/core/utils/balance_resolution.dart`
- Test: `test/core/utils/balance_resolution_test.dart`

**Interfaces:**
- Produces: `T resolveOnFetch<T>({required T previous, required bool ok, required T onSuccess})`. Tasks 2 and 3 consume this exact function.

- [ ] **Step 1: Write the failing tests**

Create `test/core/utils/balance_resolution_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/utils/balance_resolution.dart';

void main() {
  group('resolveOnFetch', () {
    test('returns the new value on success', () {
      final result = resolveOnFetch<double?>(previous: 10.0, ok: true, onSuccess: 25.0);
      expect(result, 25.0);
    });

    test('preserves the previous value on failure', () {
      final result = resolveOnFetch<double?>(previous: 10.0, ok: false, onSuccess: 25.0);
      expect(result, 10.0);
    });

    test('works with non-nullable String values (Dialpad-style balance text)', () {
      expect(resolveOnFetch<String>(previous: '\$5.00', ok: true, onSuccess: '\$7.50'), '\$7.50');
      expect(resolveOnFetch<String>(previous: '\$5.00', ok: false, onSuccess: '\$7.50'), '\$5.00');
    });

    test('preserves null when nothing has ever loaded and the fetch fails', () {
      final result = resolveOnFetch<double?>(previous: null, ok: false, onSuccess: 25.0);
      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/utils/balance_resolution_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package ... balance_resolution.dart` (file doesn't exist yet)

- [ ] **Step 3: Implement `resolveOnFetch`**

Create `lib/core/utils/balance_resolution.dart`:

```dart
/// Returns the balance value a fetch attempt should result in.
///
/// On success (`ok == true`), the newly-fetched value replaces the
/// previous one. On failure (`ok == false`), the previous value is
/// returned unchanged — a failed refresh must never clear an
/// already-displayed balance.
T resolveOnFetch<T>({required T previous, required bool ok, required T onSuccess}) {
  return ok ? onSuccess : previous;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/utils/balance_resolution_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/balance_resolution.dart test/core/utils/balance_resolution_test.dart
git commit -m "feat(balance): add resolveOnFetch helper to preserve balance on fetch failure"
```

---

### Task 2: Fix `AccountSummaryViewModel` — preserve on failure, return success, fix DI lifetime

**Files:**
- Modify: `lib/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart`
- Modify: `lib/core/di/inject.dart:107`

**Interfaces:**
- Consumes: `resolveOnFetch` (Task 1).
- Produces: `Future<bool> fetchBalance()` (was `Future<void>`) — Task 4 (`BalanceRefreshCoordinator`) and Task 5 (wiring) consume this exact signature. `getIt<AccountSummaryViewModel>()` now always resolves the same instance app-wide.

**Testing scope note:** the spec calls for a ViewModel-level test of "failure preserves the previous value." `AccountSummaryViewModel` has no injectable seam for `PaymentsClient`'s network behavior (it's a concrete class wrapping a real gRPC channel, not an interface), so exercising a real failure here would mean either a slow/flaky live network call in the test suite or a larger DI refactor outside this plan's scope. The "preserve on failure" *rule* itself is exactly what Task 1's `resolveOnFetch` tests prove in isolation; this task's own verification is `dart analyze` (the change is a small, direct application of that already-tested rule) plus Task 7's manual verification against a simulated backend outage. Flagging this explicitly rather than silently dropping the spec's testing ask.

- [ ] **Step 1: Fix the DI registration lifetime**

In `lib/core/di/inject.dart`, change:

```dart
  getIt.registerFactory(() => AccountSummaryViewModel(getIt<OtpAuthService>(), getIt<PaymentsClient>()));
```

to:

```dart
  getIt.registerLazySingleton(() => AccountSummaryViewModel(getIt<OtpAuthService>(), getIt<PaymentsClient>()));
```

- [ ] **Step 2: Add the import and fix `_fetchPaymentsBalance`/`fetchBalance`**

In `lib/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart`, add the import alongside the existing ones:

```dart
import '../../../../core/utils/balance_resolution.dart';
```

Change:

```dart
  Future<void> _fetchPaymentsBalance(String username,
      {required String password}) async {
    _paymentsLoading = true;
    notifyListeners();
    try {
      final resp = await _paymentsClient.dealerAccountBalances(
        username: username,
        password: password,
      );

      final ok =
          resp.status == Status.SUCCESSFUL || resp.status == Status.INFORMATION;
      _paymentsBalance = ok ? resp.balance : null;

      debugPrint('[Balance] status=${resp.status}  balance=${resp.balance}');
    } catch (e) {
      debugPrint('[Balance] error: $e');
    } finally {
      _paymentsLoading = false;
      notifyListeners();
    }
  }

  /// Refresh only the RTGS balance without re-loading the full user summary.
  /// Use this for quick wallet-card refresh.
  Future<void> fetchBalance() async {
    final creds = await _authService.getStoredCredentials();
    if (creds == null) return;
    final username = creds['username'];
    final password = creds['password'] ?? '';
    if (username == null) return;
    await _fetchPaymentsBalance(username, password: password);
  }
```

to:

```dart
  Future<bool> _fetchPaymentsBalance(String username,
      {required String password}) async {
    _paymentsLoading = true;
    notifyListeners();
    var ok = false;
    try {
      final resp = await _paymentsClient.dealerAccountBalances(
        username: username,
        password: password,
      );

      ok = resp.status == Status.SUCCESSFUL || resp.status == Status.INFORMATION;
      _paymentsBalance = resolveOnFetch(
        previous: _paymentsBalance,
        ok: ok,
        onSuccess: resp.balance,
      );

      debugPrint('[Balance] status=${resp.status}  balance=${resp.balance}');
    } catch (e) {
      debugPrint('[Balance] error: $e');
    } finally {
      _paymentsLoading = false;
      notifyListeners();
    }
    return ok;
  }

  /// Refresh only the RTGS balance without re-loading the full user summary.
  /// Use this for quick wallet-card refresh. Returns `true` if the fetch
  /// succeeded (balance updated), `false` otherwise (previous balance kept).
  Future<bool> fetchBalance() async {
    final creds = await _authService.getStoredCredentials();
    if (creds == null) return false;
    final username = creds['username'];
    final password = creds['password'] ?? '';
    if (username == null) return false;
    return _fetchPaymentsBalance(username, password: password);
  }
```

(The `Future.wait([_fetchUserSummary(...), _fetchPaymentsBalance(...)])` call inside `loadCurrentUser()` is unaffected — its element results are already ignored there, and a `Future<bool>` list element is a valid `Future.wait` input alongside a `Future<void>` one.)

- [ ] **Step 3: Verify it compiles**

Run: `dart analyze lib/features/account_summary/ lib/core/di/inject.dart lib/core/utils/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart lib/core/di/inject.dart
git commit -m "fix(account-summary): preserve balance on fetch failure; fix single-instance DI lifetime"
```

---

### Task 3: Fix `DialpadViewModel.loadAccountInfo()` — preserve on failure, return success

**Files:**
- Modify: `lib/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart`

**Interfaces:**
- Consumes: `resolveOnFetch` (Task 1).
- Produces: `Future<bool> loadAccountInfo()` (was `Future<void>`) — Task 4 and Task 5 consume this exact signature.

**Testing scope note:** same reasoning as Task 2 — `DialpadViewModel` wraps a real `PaymentsClient`/`OtpAuthService` with no injectable test seam, so this task's verification is `dart analyze` plus Task 7's manual check; the underlying preserve-on-failure rule is already proven in isolation by Task 1's `resolveOnFetch` tests.

- [ ] **Step 1: Add the import and fix `loadAccountInfo`**

In `lib/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart`, add the import alongside the existing ones:

```dart
import '../../../../core/utils/balance_resolution.dart';
```

Change:

```dart
  Future<void> loadAccountInfo() async {
    final creds = await authService.getStoredCredentials();
    if (creds != null && creds['username'] != null) {
      final username = creds['username']!;
      final summary = await authService.fetchAccountSummary(username, password: creds['password']);
      if (summary != null) {
        final bal = summary['balance'];
        final balNum = bal is num ? bal.toDouble() : 0.0;
        _voiceBalance = _formatVoiceBalance(balNum);
        _scheduleNotify();
      }

      final resp = await paymentsClient.dealerAccountBalances(
        username: username,
        password: creds['password'] ?? '',
      );
      final ok = resp.status == Status.SUCCESSFUL || resp.status == Status.INFORMATION;
      _accountBalance = ok ? '\$${resp.balance.toStringAsFixed(2)}' : '';
      _scheduleNotify();
    }
  }
```

to:

```dart
  /// Loads the voice-minutes and account balance for the logged-in user.
  /// Returns `true` if the account-balance fetch succeeded (balance
  /// updated), `false` otherwise (previous balance kept) — mirrors
  /// `AccountSummaryViewModel.fetchBalance()`'s contract.
  Future<bool> loadAccountInfo() async {
    final creds = await authService.getStoredCredentials();
    if (creds == null || creds['username'] == null) return false;

    final username = creds['username']!;
    final summary = await authService.fetchAccountSummary(username, password: creds['password']);
    if (summary != null) {
      final bal = summary['balance'];
      final balNum = bal is num ? bal.toDouble() : 0.0;
      _voiceBalance = _formatVoiceBalance(balNum);
      _scheduleNotify();
    }

    final resp = await paymentsClient.dealerAccountBalances(
      username: username,
      password: creds['password'] ?? '',
    );
    final ok = resp.status == Status.SUCCESSFUL || resp.status == Status.INFORMATION;
    _accountBalance = resolveOnFetch(
      previous: _accountBalance,
      ok: ok,
      onSuccess: '\$${resp.balance.toStringAsFixed(2)}',
    );
    _scheduleNotify();
    return ok;
  }
```

- [ ] **Step 2: Verify it compiles**

Run: `dart analyze lib/features/dialpad/ lib/core/utils/`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart
git commit -m "fix(dialpad): preserve balance on fetch failure, return fetch success"
```

---

### Task 4: `BalanceRefreshCoordinator`

**Files:**
- Create: `lib/core/services/balance_refresh_coordinator.dart`
- Test: `test/core/services/balance_refresh_coordinator_test.dart`
- Modify: `pubspec.yaml` (add `fake_async` as an explicit dev dependency)

**Interfaces:**
- Consumes: nothing concrete — takes three injected callbacks (`Future<bool> Function() refreshAccountSummary`, `Future<bool> Function() refreshDialpad`, `void Function() showRetryingNotice`), so it has no compile-time dependency on `AccountSummaryViewModel`/`DialpadViewModel`/Flutter widgets.
- Produces: `class BalanceRefreshCoordinator` with `Future<void> refreshAfterCall()` and `bool get isRefreshing`. Task 5 (wiring) constructs this with real callbacks.

- [ ] **Step 1: Add the `fake_async` dev dependency**

In `pubspec.yaml`, under `dev_dependencies:`, add:

```yaml
  fake_async: ^1.3.3
```

Run: `flutter pub get`
Expected: resolves cleanly (already a transitive dependency, so no version conflict).

- [ ] **Step 2: Write the failing tests**

Create `test/core/services/balance_refresh_coordinator_test.dart`:

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/services/balance_refresh_coordinator.dart';

void main() {
  group('BalanceRefreshCoordinator', () {
    test('both succeed on the first attempt: no retry, no notice', () {
      fakeAsync((async) {
        var accountCalls = 0;
        var dialpadCalls = 0;
        var noticeShown = 0;

        final coordinator = BalanceRefreshCoordinator(
          refreshAccountSummary: () async {
            accountCalls++;
            return true;
          },
          refreshDialpad: () async {
            dialpadCalls++;
            return true;
          },
          showRetryingNotice: () => noticeShown++,
        );

        coordinator.refreshAfterCall();
        async.flushMicrotasks();

        expect(accountCalls, 1);
        expect(dialpadCalls, 1);
        expect(noticeShown, 0);
        expect(coordinator.isRefreshing, isFalse);
      });
    });

    test('account fails then succeeds on the first retry: one notice, no unnecessary dialpad retry', () {
      fakeAsync((async) {
        var accountCalls = 0;
        var dialpadCalls = 0;
        var noticeShown = 0;

        final coordinator = BalanceRefreshCoordinator(
          refreshAccountSummary: () async {
            accountCalls++;
            return accountCalls > 1; // fails first time, succeeds on retry
          },
          refreshDialpad: () async {
            dialpadCalls++;
            return true;
          },
          showRetryingNotice: () => noticeShown++,
        );

        coordinator.refreshAfterCall();
        async.elapse(const Duration(seconds: 20));

        expect(accountCalls, 2);
        expect(dialpadCalls, 1);
        expect(noticeShown, 1);
        expect(coordinator.isRefreshing, isFalse);
      });
    });

    test('all attempts fail: notice shown exactly once, gives up silently after 4 total tries', () {
      fakeAsync((async) {
        var accountCalls = 0;
        var dialpadCalls = 0;
        var noticeShown = 0;

        final coordinator = BalanceRefreshCoordinator(
          refreshAccountSummary: () async {
            accountCalls++;
            return false;
          },
          refreshDialpad: () async {
            dialpadCalls++;
            return false;
          },
          showRetryingNotice: () => noticeShown++,
        );

        coordinator.refreshAfterCall();
        async.elapse(const Duration(seconds: 20));

        expect(accountCalls, 4); // 1 initial + 3 retries
        expect(dialpadCalls, 4);
        expect(noticeShown, 1);
        expect(coordinator.isRefreshing, isFalse);
      });
    });

    test('a second trigger while a refresh is in flight is a no-op', () {
      fakeAsync((async) {
        var accountCalls = 0;

        final coordinator = BalanceRefreshCoordinator(
          refreshAccountSummary: () async {
            accountCalls++;
            await Future<void>.delayed(const Duration(seconds: 1));
            return true;
          },
          refreshDialpad: () async => true,
          showRetryingNotice: () {},
        );

        coordinator.refreshAfterCall();
        coordinator.refreshAfterCall();
        async.elapse(const Duration(seconds: 2));

        expect(accountCalls, 1);
      });
    });
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/core/services/balance_refresh_coordinator_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package ... balance_refresh_coordinator.dart` (file doesn't exist yet)

- [ ] **Step 4: Implement `BalanceRefreshCoordinator`**

Create `lib/core/services/balance_refresh_coordinator.dart`:

```dart
/// Retries and coalesces balance refreshes triggered by a call ending.
///
/// Depends only on simple function-shaped callbacks rather than concrete
/// ViewModels, so it has no Flutter/network dependencies of its own and is
/// fully unit-testable. The two balance-fetch callbacks are expected to
/// return `true` on success and `false` on failure, and to already
/// preserve their own last-known value on failure (see `resolveOnFetch`
/// in `lib/core/utils/balance_resolution.dart`) — this coordinator only
/// decides *when* to call them and *when* to notify the user, never what
/// value to display.
class BalanceRefreshCoordinator {
  BalanceRefreshCoordinator({
    required Future<bool> Function() refreshAccountSummary,
    required Future<bool> Function() refreshDialpad,
    required void Function() showRetryingNotice,
  })  : _refreshAccountSummary = refreshAccountSummary,
        _refreshDialpad = refreshDialpad,
        _showRetryingNotice = showRetryingNotice;

  final Future<bool> Function() _refreshAccountSummary;
  final Future<bool> Function() _refreshDialpad;
  final void Function() _showRetryingNotice;

  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  bool _refreshing = false;

  /// Whether a refresh sequence is currently in flight. A second call to
  /// [refreshAfterCall] while this is true is a no-op.
  bool get isRefreshing => _refreshing;

  /// Refreshes both balance sources, retrying only whichever one(s)
  /// failed, per the 2s/5s/10s backoff schedule. No-ops if a refresh is
  /// already in flight (guards against overlapping triggers, e.g.
  /// call-waiting ending two calls in quick succession).
  Future<void> refreshAfterCall() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      var results = await Future.wait([
        _refreshAccountSummary(),
        _refreshDialpad(),
      ]);
      var accountDone = results[0];
      var dialpadDone = results[1];

      if (accountDone && dialpadDone) return;

      _showRetryingNotice();

      for (final delay in _retryDelays) {
        await Future<void>.delayed(delay);
        results = await Future.wait([
          _attempt(_refreshAccountSummary, accountDone),
          _attempt(_refreshDialpad, dialpadDone),
        ]);
        accountDone = results[0];
        dialpadDone = results[1];
        if (accountDone && dialpadDone) return;
      }
      // All attempts exhausted — give up silently. Both callbacks already
      // preserved their last-known values, so there is nothing further to do.
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> _attempt(Future<bool> Function() fetch, bool alreadyDone) {
    return alreadyDone ? Future.value(true) : fetch();
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/services/balance_refresh_coordinator_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/services/balance_refresh_coordinator.dart test/core/services/balance_refresh_coordinator_test.dart
git commit -m "feat(balance): add BalanceRefreshCoordinator with retry and coalescing"
```

---

### Task 5: Wire the coordinator into `SipCallManager` and `main.dart`

**Files:**
- Modify: `lib/core/managers/sip_call_manager.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `BalanceRefreshCoordinator` (Task 4), `AccountSummaryViewModel.fetchBalance()` (Task 2), `DialpadViewModel.loadAccountInfo()` (Task 3).
- Produces: every call ending (`ENDED` or `FAILED` state) triggers `BalanceRefreshCoordinator.refreshAfterCall()`.

- [ ] **Step 1: Add the coordinator to `SipCallManager`**

In `lib/core/managers/sip_call_manager.dart`, add the import:

```dart
import '../services/balance_refresh_coordinator.dart';
```

Change the constructor and field list:

```dart
class SipCallManager implements SipUaHelperListener {
  final SIPUAHelper _sipHelper;
  final GlobalKey<NavigatorState> navigatorKey;
  final DialpadViewModel _dialpadViewModel;

  /// Tracks when each call was answered so we can compute accurate duration.
  final Map<String, DateTime> _connectedAt = {};

  SipCallManager(this._sipHelper, this.navigatorKey, this._dialpadViewModel) {
    _sipHelper.addSipUaHelperListener(this);
  }
```

to:

```dart
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
```

Change the `ENDED` and `FAILED` switch cases:

```dart
      // ── Log completed call on end ──────────────────────────────────────────
      case CallStateEnum.ENDED:
        _handleCallEnded(call, callState, callId);

      case CallStateEnum.FAILED:
        _connectedAt.remove(callId);
        if (call.direction.toString().toUpperCase().contains('INCOMING')) {
          _logCall(call, status: 'failed', durationSeconds: null);
        }
```

to:

```dart
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
```

- [ ] **Step 2: Construct the coordinator in `main.dart` and pass it to `SipCallManager`**

In `lib/main.dart`, add the imports:

```dart
import 'core/services/balance_refresh_coordinator.dart';
```

Change:

```dart
  // Initialize SipCallManager
  final sipHelper = getIt<SIPUAHelper>();
  // ignore: unused_local_variable
  final sipCallManager = SipCallManager(
    sipHelper, 
    navigatorKey, 
    getIt<DialpadViewModel>(),
  );

  runApp(const MyApp());
```

to:

```dart
  // Initialize SipCallManager
  final sipHelper = getIt<SIPUAHelper>();
  final balanceRefreshCoordinator = BalanceRefreshCoordinator(
    refreshAccountSummary: () => getIt<AccountSummaryViewModel>().fetchBalance(),
    refreshDialpad: () => getIt<DialpadViewModel>().loadAccountInfo(),
    showRetryingNotice: () {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to refresh balance. Retrying...'),
          duration: Duration(seconds: 3),
        ),
      );
    },
  );
  // ignore: unused_local_variable
  final sipCallManager = SipCallManager(
    sipHelper, 
    navigatorKey, 
    getIt<DialpadViewModel>(),
    balanceRefreshCoordinator,
  );

  runApp(const MyApp());
```

(`getIt<AccountSummaryViewModel>()` inside the `refreshAccountSummary` closure now safely resolves the same singleton instance the `MultiProvider` uses, thanks to Task 2's DI fix — the closure re-resolves it on every call rather than capturing it once, which is harmless since it's the same singleton every time, and keeps this code from needing to care about `get_it` resolution order at startup.)

- [ ] **Step 3: Verify it compiles**

Run: `dart analyze lib/core/managers/ lib/main.dart lib/core/services/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/core/managers/sip_call_manager.dart lib/main.dart
git commit -m "feat(balance): trigger BalanceRefreshCoordinator on every call-end outcome"
```

---

### Task 6: Animate the Dialpad screen's balance display

**Files:**
- Modify: `lib/features/dialpad/presentation/views/dialpad_view.dart:243-268`

**Interfaces:**
- Consumes: `DialpadViewModel.voiceBalance`/`accountBalance` (unchanged getters).
- Produces: the Dialpad screen's balance text animates on change the same way `MasterBalanceCard` already does on Home.

- [ ] **Step 1: Wrap both balance `Text` widgets in `AnimatedSwitcher`**

In `lib/features/dialpad/presentation/views/dialpad_view.dart`, change:

```dart
              title: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Container(
                         width: 8,
                         height: 8,
                         decoration: BoxDecoration(
                           color: _sipStatusColor(viewModel),
                           shape: BoxShape.circle,
                         ),
                       ),
                       const SizedBox(width: 8),
                       Text(
                         "Voice Bal: ${viewModel.voiceBalance}",
                         style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.normal),
                       ),
                     ],
                   ),
                   Text(
                     "Balance: ${viewModel.accountBalance}",
                     style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.normal),
                   ),
                ],
              ),
```

to:

```dart
              title: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Container(
                         width: 8,
                         height: 8,
                         decoration: BoxDecoration(
                           color: _sipStatusColor(viewModel),
                           shape: BoxShape.circle,
                         ),
                       ),
                       const SizedBox(width: 8),
                       AnimatedSwitcher(
                         duration: const Duration(milliseconds: 320),
                         switchInCurve: Curves.easeOutCubic,
                         switchOutCurve: Curves.easeInCubic,
                         transitionBuilder: (child, anim) => FadeTransition(
                           opacity: anim,
                           child: SlideTransition(
                             position: Tween<Offset>(
                               begin: const Offset(0, 0.08),
                               end: Offset.zero,
                             ).animate(anim),
                             child: child,
                           ),
                         ),
                         child: Text(
                           "Voice Bal: ${viewModel.voiceBalance}",
                           key: ValueKey<String>('voice_${viewModel.voiceBalance}'),
                           style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.normal),
                         ),
                       ),
                     ],
                   ),
                   AnimatedSwitcher(
                     duration: const Duration(milliseconds: 320),
                     switchInCurve: Curves.easeOutCubic,
                     switchOutCurve: Curves.easeInCubic,
                     transitionBuilder: (child, anim) => FadeTransition(
                       opacity: anim,
                       child: SlideTransition(
                         position: Tween<Offset>(
                           begin: const Offset(0, 0.08),
                           end: Offset.zero,
                         ).animate(anim),
                         child: child,
                       ),
                     ),
                     child: Text(
                       "Balance: ${viewModel.accountBalance}",
                       key: ValueKey<String>('account_${viewModel.accountBalance}'),
                       style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.normal),
                     ),
                   ),
                ],
              ),
```

- [ ] **Step 2: Verify it compiles**

Run: `dart analyze lib/features/dialpad/`
Expected: `No issues found!`

- [ ] **Step 3: Manual verification**

Run the app, open the Dialpad screen, and confirm the balance lines still render correctly (no layout shift/overflow from the `AnimatedSwitcher` wrapping).

- [ ] **Step 4: Commit**

```bash
git add lib/features/dialpad/presentation/views/dialpad_view.dart
git commit -m "feat(dialpad): animate balance text updates on the Dialpad screen"
```

---

### Task 7: Final verification pass

**Files:** none (verification only)

- [ ] **Step 1: Full static analysis**

Run: `dart analyze`
Expected: `No issues found!` (aside from any pre-existing, unrelated issues that predate this plan).

- [ ] **Step 2: Focused test suites**

Run: `flutter test test/core/utils/ test/core/services/`
Expected: `All tests passed!`

- [ ] **Step 3: Manual run-through**

With a real backend and SIP account available: make a call and let it complete normally — confirm Home's wallet card and the Dialpad screen's balance both update within ~1-2 seconds with a smooth animation, no navigation or manual refresh needed. Repeat for a missed call, a declined call, and (if reproducible) a failed call. Then simulate a backend outage (e.g., point the payments/voice endpoints at an unreachable host) and end a call — confirm the "Unable to refresh balance. Retrying..." snackbar appears exactly once, the previously-displayed balance never disappears, and it stops retrying quietly after the fourth attempt.

- [ ] **Step 4: Report results to the user**

Summarize what was verified and flag anything that didn't match the spec before considering the feature done.
