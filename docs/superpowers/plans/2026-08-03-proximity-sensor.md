# Proximity Sensor (Screen Off During Calls) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the screen off (via the OS's native proximity behavior) when a connected, voice-only, non-speakerphone call is held to the ear, and restore it immediately when it isn't.

**Architecture:** A thin `ProximitySensorGateway` interface wraps the third-party `proximity_sensor` package. A plain-Dart `ProximityScreenController` (no Flutter/ViewModel imports) owns the enable/disable lifecycle behind that interface and is fully unit-testable via a hand-rolled fake. `CallView` — which already owns platform-level, state-driven side effects (ringtone, pulse animation) in its single `_onViewModelChanged()` reaction point — computes the activation condition and drives the controller from there. `CallViewModel` gains one small setter fix so `isVoiceOnly` stays accurate after a mid-call video upgrade.

**Tech Stack:** Flutter 3.38.6 / Dart 3.10.7, `proximity_sensor` package (pinned to `^1.4.0` — pub.dev's latest 2.0.0 requires Flutter ≥3.44.0, which this project doesn't have), `provider` (existing `ChangeNotifier` pattern), `flutter_test`.

## Global Constraints

- Package pin: `proximity_sensor: ^1.4.0` exactly — do not let this float to 2.0.0+ (incompatible with this project's Flutter SDK).
- Activation condition (exact): `phoneState == PhoneCallState.connected && viewModel.isVoiceOnly && !viewModel.isSpeakerOn`. No other `PhoneCallState` activates it.
- No settings toggle — always on for eligible calls, no persisted preference.
- No `AndroidManifest.xml` or `Info.plist` changes — none are needed (`WAKE_LOCK` already declared; no runtime permission applies to this feature on either platform).
- Android ordering constraint: `ProximitySensorGateway.setScreenOffEnabled(true)` **must** be called and awaited before subscribing to `.events` — the native wake lock is only acquired if this flag was already set at the moment the stream is first listened to.
- A missing/faulty proximity sensor must never affect call functionality — failures are caught and logged, never thrown past `ProximityScreenController`.

---

### Task 1: `ProximitySensorGateway` abstraction + dependency + DI registration

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/services/proximity_sensor_gateway.dart`
- Modify: `lib/core/di/inject.dart`

**Interfaces:**
- Produces: `abstract class ProximitySensorGateway { Stream<int> get events; Future<void> setScreenOffEnabled(bool enabled); }` and `class PackageProximitySensorGateway implements ProximitySensorGateway`. Task 2 depends on the `ProximitySensorGateway` interface (not the concrete class). Task 3 depends on `getIt<ProximitySensorGateway>()` resolving to a `PackageProximitySensorGateway`.

This task has no dedicated unit test: `PackageProximitySensorGateway` is a 1:1 delegation to static package calls with zero branching logic of its own — the same deliberate scoping already used in this codebase for thin network/platform wrappers (e.g. `PaymentsClient`, `UsersClient` aren't unit-tested directly; their callers are, via the abstraction they expose). `ProximityScreenController`, which Task 2 tests thoroughly, is what actually holds the logic.

- [ ] **Step 1: Add the pinned dependency**

Add this line under the `dependencies:` section of `pubspec.yaml`, near the other recently-pinned platform packages (`share_plus`, `file_picker`):

```yaml
  proximity_sensor: ^1.4.0
```

- [ ] **Step 2: Fetch it and verify the resolved version**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter pub get`

Then run: `/home/user/snap/flutter/common/flutter/bin/flutter pub deps | grep proximity_sensor`

Expected: resolves to exactly `proximity_sensor 1.4.0`. If it resolves to anything in the `2.x` line, stop — that means the local Flutter SDK changed since this plan was written (2.0.0 requires Flutter ≥3.44.0) and the plan's assumptions about the package's native behavior (verified against 1.4.0's actual source) need re-checking before proceeding.

- [ ] **Step 3: Write the gateway abstraction**

Create `lib/core/services/proximity_sensor_gateway.dart`:

```dart
import 'package:proximity_sensor/proximity_sensor.dart';

/// Abstraction over the third-party `proximity_sensor` package so nothing
/// else in the app depends on it directly. On [events], `0` means far,
/// `1` means near.
abstract class ProximitySensorGateway {
  Stream<int> get events;

  /// Android-only; a no-op on other platforms (the package itself guards
  /// this). Must be called with `true` and awaited *before* subscribing to
  /// [events] — the native implementation only acquires the screen-off
  /// wake lock if this flag was already set at the moment the stream is
  /// first listened to.
  Future<void> setScreenOffEnabled(bool enabled);
}

class PackageProximitySensorGateway implements ProximitySensorGateway {
  @override
  Stream<int> get events => ProximitySensor.events;

  @override
  Future<void> setScreenOffEnabled(bool enabled) =>
      ProximitySensor.setProximityScreenOff(enabled);
}
```

- [ ] **Step 4: Register it in DI**

In `lib/core/di/inject.dart`, add the import near the other service imports (after `import '../../services/shipping_address_service.dart';`):

```dart
import '../services/proximity_sensor_gateway.dart';
```

Add the registration near the other `services` registrations (after the `getIt.registerLazySingleton<ShippingAddressService>(...)`-style block, alongside `CallingService`/`ShoppingService`/etc.):

```dart
  getIt.registerLazySingleton<ProximitySensorGateway>(
      () => PackageProximitySensorGateway());
```

- [ ] **Step 5: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/core/services/proximity_sensor_gateway.dart lib/core/di/inject.dart`

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/services/proximity_sensor_gateway.dart lib/core/di/inject.dart
git commit -m "feat(proximity): add ProximitySensorGateway abstraction and DI registration"
```

---

### Task 2: `ProximityScreenController`

**Files:**
- Create: `lib/core/services/proximity_screen_controller.dart`
- Create: `test/core/services/proximity_screen_controller_test.dart`

**Interfaces:**
- Consumes: `ProximitySensorGateway` (from Task 1) — `Stream<int> get events`, `Future<void> setScreenOffEnabled(bool enabled)`.
- Produces: `class ProximityScreenController { ProximityScreenController(ProximitySensorGateway gateway); bool get isActive; Future<void> setActive(bool active); Future<void> dispose(); }`. Task 3 depends on this exact constructor and these three members.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/proximity_screen_controller_test.dart`:

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/services/proximity_screen_controller.dart';
import 'package:mvvm_sip_demo/core/services/proximity_sensor_gateway.dart';

class FakeProximitySensorGateway implements ProximitySensorGateway {
  final _controller = StreamController<int>.broadcast();
  final List<String> callLog = [];

  @override
  Stream<int> get events {
    callLog.add('listen');
    return _controller.stream;
  }

  @override
  Future<void> setScreenOffEnabled(bool enabled) async {
    callLog.add(enabled ? 'screenOff(true)' : 'screenOff(false)');
  }

  void emitError(Object error) => _controller.addError(error);

  Future<void> close() => _controller.close();
}

void main() {
  group('ProximityScreenController', () {
    late FakeProximitySensorGateway gateway;
    late ProximityScreenController controller;

    setUp(() {
      gateway = FakeProximitySensorGateway();
      controller = ProximityScreenController(gateway);
    });

    tearDown(() async {
      await controller.dispose();
      await gateway.close();
    });

    test('setActive(true) enables screen-off before subscribing to events', () async {
      expect(controller.isActive, isFalse);

      await controller.setActive(true);

      expect(gateway.callLog, ['screenOff(true)', 'listen']);
      expect(controller.isActive, isTrue);
    });

    test('setActive(false) after active cancels the subscription and disables screen-off', () async {
      await controller.setActive(true);

      await controller.setActive(false);

      expect(gateway.callLog, ['screenOff(true)', 'listen', 'screenOff(false)']);
      expect(controller.isActive, isFalse);
    });

    test('redundant setActive calls with the same value do not re-invoke the gateway', () async {
      await controller.setActive(true);
      await controller.setActive(true);
      await controller.setActive(true);

      expect(gateway.callLog, ['screenOff(true)', 'listen']);

      await controller.setActive(false);
      await controller.setActive(false);

      expect(gateway.callLog, ['screenOff(true)', 'listen', 'screenOff(false)']);
    });

    test('a stream error marks the controller inactive without throwing', () async {
      await controller.setActive(true);
      expect(controller.isActive, isTrue);

      gateway.emitError(Exception('sensor unavailable'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.isActive, isFalse);
    });

    test('dispose() is safe to call without ever activating', () async {
      await controller.dispose();
      expect(controller.isActive, isFalse);
    });

    test('dispose() while active deactivates cleanly', () async {
      await controller.setActive(true);

      await controller.dispose();

      expect(controller.isActive, isFalse);
      expect(gateway.callLog, ['screenOff(true)', 'listen', 'screenOff(false)']);
    });

    test('overlapping setActive calls are serialized, not interleaved', () async {
      final first = controller.setActive(true);
      final second = controller.setActive(false);
      await Future.wait([first, second]);

      expect(gateway.callLog, ['screenOff(true)', 'listen', 'screenOff(false)']);
      expect(controller.isActive, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/core/services/proximity_screen_controller_test.dart`

Expected: FAIL — `proximity_screen_controller.dart` does not exist yet (import error).

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/proximity_screen_controller.dart`:

```dart
import 'dart:async';

import 'proximity_sensor_gateway.dart';

/// Drives the device's native proximity screen-off behavior on and off
/// (a real `PowerManager` wake lock on Android, `UIDevice` proximity
/// monitoring on iOS — see [ProximitySensorGateway]). A missing or
/// misbehaving sensor never throws past this class; it just leaves
/// [isActive] `false`.
///
/// Calls to [setActive] are serialized internally so overlapping calls
/// (e.g. two `notifyListeners()` events firing close together) can never
/// interleave mid-await and leak a subscription or wake lock.
class ProximityScreenController {
  ProximityScreenController(this._gateway);

  final ProximitySensorGateway _gateway;
  StreamSubscription<int>? _subscription;
  bool _isActive = false;
  Future<void> _pending = Future<void>.value();

  bool get isActive => _isActive;

  Future<void> setActive(bool active) {
    _pending = _pending.then((_) => _setActive(active));
    return _pending;
  }

  Future<void> _setActive(bool active) async {
    if (active == _isActive) return;

    if (active) {
      await _gateway.setScreenOffEnabled(true);
      _subscription = _gateway.events.listen(
        (_) {},
        onError: (Object _) {
          _isActive = false;
          _subscription?.cancel();
          _subscription = null;
        },
      );
      _isActive = true;
    } else {
      final subscription = _subscription;
      _subscription = null;
      await subscription?.cancel();
      await _gateway.setScreenOffEnabled(false);
      _isActive = false;
    }
  }

  Future<void> dispose() => setActive(false);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/core/services/proximity_screen_controller_test.dart`

Expected: `+7: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/proximity_screen_controller.dart test/core/services/proximity_screen_controller_test.dart
git commit -m "feat(proximity): add ProximityScreenController with serialized activate/deactivate"
```

---

### Task 3: Wire into `CallView` + fix `isVoiceOnly` staleness on video upgrade

**Files:**
- Modify: `lib/features/call/presentation/viewmodels/call_viewmodel.dart`
- Modify: `lib/features/call/presentation/views/call_view.dart`

**Interfaces:**
- Consumes: `ProximityScreenController` and `ProximitySensorGateway` (Tasks 1-2), `getIt<ProximitySensorGateway>()`.
- Produces: `CallViewModel.setVoiceOnly(bool voiceOnly)` — a plain setter, no other task depends on it beyond this one.

This task has no new automated test: `CallView` has no existing widget-test harness (verified — nothing under `test/` exercises it), and building one from scratch (fake `SIPUAHelper`/`Call`) is out of scope for this feature, matching `CallView`'s current untested state. Correctness here is covered by a manual verification pass in Task 4.

- [ ] **Step 1: Fix `isVoiceOnly` staleness on mid-call video upgrade**

In `lib/features/call/presentation/viewmodels/call_viewmodel.dart`, add this method right after `setRemoteIdentity` (around line 294):

```dart
  /// Updates voice/video mode outside the normal call-setup paths — e.g.
  /// when a mid-call re-invite upgrades a voice call to video. No-ops if
  /// the value doesn't change.
  void setVoiceOnly(bool voiceOnly) {
    if (_isVoiceOnly == voiceOnly) return;
    _isVoiceOnly = voiceOnly;
    notifyListeners();
  }
```

Why: `onNewReinvite`'s accept handler in `call_view.dart` currently does `setState(() => widget.call.voiceOnly = false)` on video-upgrade accept, which updates the View's local copy of the `Call` object but never tells `CallViewModel._isVoiceOnly` — so `viewModel.isVoiceOnly` (what our proximity check and the `build()` method's video/voice scaffold branch both read) stays stale as `true` after the upgrade. This was a pre-existing gap; it becomes directly relevant now because our proximity feature depends on `isVoiceOnly` being accurate.

- [ ] **Step 2: Call the new setter from the reinvite accept handler**

In `lib/features/call/presentation/views/call_view.dart`, find this block inside `onNewReinvite` (around line 823-830):

```dart
            TextButton(
              child: const Text('Accept'),
              onPressed: () {
                event.accept!.call({});
                setState(() => widget.call.voiceOnly = false);
                Navigator.of(ctx).pop();
              },
            ),
```

Change it to:

```dart
            TextButton(
              child: const Text('Accept'),
              onPressed: () {
                event.accept!.call({});
                _viewModel.setVoiceOnly(false);
                setState(() => widget.call.voiceOnly = false);
                Navigator.of(ctx).pop();
              },
            ),
```

- [ ] **Step 3: Add the proximity controller field and imports**

In `lib/features/call/presentation/views/call_view.dart`, add these imports alongside the existing ones near the top of the file:

```dart
import '../../../../core/services/proximity_screen_controller.dart';
import '../../../../core/services/proximity_sensor_gateway.dart';
```

Add a new field in `_CallViewState`, alongside `late SIPUAHelper _sipHelper;`:

```dart
  late final ProximityScreenController _proximityController;
```

- [ ] **Step 4: Construct it in `initState`**

In `initState()`, right after `_sipHelper = getIt<SIPUAHelper>();`, add:

```dart
    _proximityController =
        ProximityScreenController(getIt<ProximitySensorGateway>());
```

- [ ] **Step 5: Drive it from `_onViewModelChanged`**

In `_onViewModelChanged()`, the method currently looks like:

```dart
  void _onViewModelChanged() {
    final state = _viewModel.phoneState;

    // Sync animation.
    if (state.isPreConnect) {
      if (!_pulseController.isAnimating) _pulseController.repeat();
    } else {
      if (_pulseController.isAnimating) _pulseController.stop();
    }

    // Sync audio — only change if state changed.
    if (_lastAudioState == state) return;
    _lastAudioState = state;

    switch (state) {
```

Insert the proximity sync **between** the animation sync and the audio-state early-return — it must run on *every* call to this method (including a speaker toggle, which changes nothing about `phoneState`), not just when `state` itself changes, so it has to sit above the `if (_lastAudioState == state) return;` guard:

```dart
  void _onViewModelChanged() {
    final state = _viewModel.phoneState;

    // Sync animation.
    if (state.isPreConnect) {
      if (!_pulseController.isAnimating) _pulseController.repeat();
    } else {
      if (_pulseController.isAnimating) _pulseController.stop();
    }

    // Sync proximity screen-off. Must run on every change (including
    // speaker toggling, which doesn't change `state`), so this sits above
    // the audio-state early-return below rather than inside the switch.
    final shouldMonitorProximity = state == PhoneCallState.connected &&
        _viewModel.isVoiceOnly &&
        !_viewModel.isSpeakerOn;
    _proximityController.setActive(shouldMonitorProximity);

    // Sync audio — only change if state changed.
    if (_lastAudioState == state) return;
    _lastAudioState = state;

    switch (state) {
```

- [ ] **Step 6: Dispose it**

In `dispose()`, add the call alongside the other cleanup (not awaited — same fire-and-forget style already used for `_audioPlayer.stop()` in this same method; releasing the wake lock is best-effort and must not block widget disposal):

```dart
  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.resetForDispose();
    _pulseController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _proximityController.dispose();
    _endScreenTimer?.cancel();
    _sipHelper.removeSipUaHelperListener(this);
    _disposeRenderers();
    _cleanUp();
    super.dispose();
  }
```

- [ ] **Step 7: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/features/call`

Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/call/presentation/viewmodels/call_viewmodel.dart lib/features/call/presentation/views/call_view.dart
git commit -m "feat(proximity): wire ProximityScreenController into CallView"
```

---

### Task 4: Final verification pass

**Files:** None (verification only).

- [ ] **Step 1: Full project analyze**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze`

Expected: only the pre-existing, unrelated issues already known from prior work in this repo (an unused import in `otp_auth_service.dart` and a handful of `withOpacity`/`BuildContext`-across-async-gap infos elsewhere) — zero new issues introduced by this plan.

- [ ] **Step 2: Run the focused test suite for this feature**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/core/services/proximity_screen_controller_test.dart`

Expected: `+7: All tests passed!`

- [ ] **Step 3: Confirm no other test file references anything this plan touched**

Run: `grep -rl "CallViewModel\|CallView\b" test/ 2>/dev/null`

Expected: no output (no existing test constructs `CallViewModel` or `CallView` directly, so the `setVoiceOnly` addition and `CallView` changes can't have broken an existing test). If this turns up a file, read it and confirm it still passes before proceeding.

- [ ] **Step 4: Note the manual verification that remains**

Record in the task report (not a new file) that a real-device pass is still needed and is environment-blocked here, matching the same precedent already established for this app's balance auto-refresh plan: place a call, connect, cover the sensor → screen dims; uncover → screen restores; toggle speaker while covered → screen restores immediately; end the call while covered → screen restores within the 2s end-screen window.
