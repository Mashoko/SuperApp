# Proximity Sensor (Screen Off During Calls) — Design Spec

Date: 2026-08-03
Status: Approved, pending implementation plan

## Context

This is the third of three independent calling-experience improvements
requested together (balance auto-refresh, a call-logs overhaul, and this
proximity-sensor feature) — each is a separate sub-project with its own
spec; this spec covers the proximity sensor only. Balance auto-refresh
shipped first (`docs/superpowers/specs/2026-07-30-balance-auto-refresh-design.md`).

Today, the in-call screen (`CallView`, `lib/features/call/presentation/views/call_view.dart`)
never turns the screen off when the phone is held to the ear — the display
stays on for the full duration of a voice call, unlike a standard phone
dialer.

Discovered while scoping this spec:
- No proximity/wakelock package exists in this app yet. `pubspec.yaml` has
  no dependency for this, and neither `android/app/src/main/kotlin/.../MainActivity.kt`
  nor `ios/Runner/AppDelegate.swift` has any custom platform-channel code —
  both are stock/default.
- True "screen off near ear" is an OS-level behavior, not something Flutter
  can fake with a black overlay: Android exposes it via
  `PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK`, iOS via
  `UIDevice.isProximityMonitoringEnabled` (which triggers Apple's own
  call-screen dimming).
- The `proximity_sensor` package wraps both natively. Its **latest pub.dev
  version (2.0.0) requires Flutter ≥3.44.0**, but this project runs Flutter
  3.38.6 (`flutter --version`), so pub's solver resolves to **1.4.0** —
  verified by downloading and reading the actual 1.4.0 source (not the
  package's newer `main` branch, which has since diverged):
  - Android (`ProximityStreamHandler.kt`): `onListen` acquires a real
    `PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK` *if* `setProximityScreenOff(true)`
    was called before the stream was subscribed to; `onCancel` releases it.
    Gracefully checks `Sensor.TYPE_PROXIMITY` availability via
    `isProximitySensorAvailable()`, and `onListen` throws
    `UnsupportedOperationException` if the hardware is missing — **correction
    made during final review:** this does *not* surface as a stream error.
    Flutter's `EventChannel.receiveBroadcastStream` routes an `onListen`
    throw to `FlutterError.reportError`, not to the stream's `onError`; the
    listen call itself simply returns without ever emitting an event. In
    practice this is still safe (no wake lock is taken, cleanup is a
    no-op), but `ProximityScreenController`'s `onError` handler cannot
    actually be triggered by a missing sensor on either platform — it is
    defensive depth for a path this package doesn't exercise, not the
    mechanism that makes a missing sensor safe.
  - iOS (`SwiftProximitySensorPlugin.swift`): `onListen` sets
    `UIDevice.current.isProximityMonitoringEnabled = true` (enabling
    Apple's native screen-dimming) and listens for
    `proximityStateDidChangeNotification`; `onCancel` disables monitoring.
    Returns gracefully (no error) if the sensor is unavailable.
  - `setProximityScreenOff` is a no-op on non-Android platforms (guarded by
    `Platform.isAndroid` inside the package itself) — safe to call
    unconditionally.
- No `AndroidManifest.xml` or `Info.plist` changes are needed: `WAKE_LOCK`
  is already declared (`android/app/src/main/AndroidManifest.xml:13`), and
  neither `Sensor.TYPE_PROXIMITY` nor `isProximityMonitoringEnabled`
  requires a runtime permission or a privacy usage string on either
  platform.
- `CallView` already owns platform-level, state-driven side effects
  (ringtone `AudioPlayer`, pulse `AnimationController`, `_endScreenTimer`)
  in a single reaction point, `_onViewModelChanged()`, which fires on every
  `CallViewModel.notifyListeners()`. This is the natural place to add
  another state-driven side effect, keeping `CallViewModel` itself free of
  platform/plugin dependencies — the same pure-ViewModel/effects-in-View
  split already established by the balance auto-refresh work.

## Goals

- While a call is `connected`, voice-only, and not on speakerphone, the
  screen turns off (via the OS's native proximity behavior) when held to
  the ear, and turns back on immediately when moved away.
- The behavior deactivates immediately — before the next frame a user could
  see — when any of the following happens: the call leaves `connected`
  (ended, missed, declined, failed), speakerphone is turned on, or the call
  becomes a video call.
- No user-facing setting. Always on for eligible calls.
- A missing or malfunctioning proximity sensor never affects call
  functionality — worst case, the screen simply doesn't turn off.

## Non-goals

- Any pre-connect activation (ringing/dialing/incoming) — only `connected`
  state is in scope, per the approved design discussion. This deliberately
  avoids screen-blanking edge cases while a user is still deciding whether
  to answer.
- A settings toggle to disable the feature.
- Any change to call-history/call-log recording or balance auto-refresh —
  each is its own sub-project.
- Special-casing hold (`isOnHold`): a call on hold remains in
  `PhoneCallState.connected`, so proximity stays active exactly as it does
  for an unheld call. No new behavior is introduced for this state.

## Architecture

**`ProximitySensorGateway`** (new, `lib/core/services/proximity_sensor_gateway.dart`) —
a thin abstraction over the third-party package, so nothing else in the app
depends on `proximity_sensor` directly:

```dart
abstract class ProximitySensorGateway {
  Stream<int> get events; // 0 = far, 1 = near
  Future<void> setScreenOffEnabled(bool enabled); // Android-only; no-op elsewhere
}
```

`PackageProximitySensorGateway` implements it by delegating to
`ProximitySensor.events` / `ProximitySensor.setProximityScreenOff`.
Registered in `lib/core/di/inject.dart` as the `ProximitySensorGateway`
implementation (registered as a lazy singleton in the actual implementation
— stateless wrapper, either registration style is safe).

**`ProximityScreenController`** (new, `lib/core/services/proximity_screen_controller.dart`) —
plain Dart class, one injected dependency (`ProximitySensorGateway`), no
Flutter/ViewModel imports of its own — same isolation principle as
`BalanceRefreshCoordinator`:

```dart
class ProximityScreenController {
  ProximityScreenController(this._gateway);
  final ProximitySensorGateway _gateway;

  bool get isActive;

  Future<void> setActive(bool active); // idempotent no-op if already in that state
  Future<void> dispose();              // safe even if never activated
}
```

`setActive(true)`:
1. `await _gateway.setScreenOffEnabled(true)` — **must** happen before
   subscribing, since Android's wake lock is only acquired if this flag was
   already set at the moment `.events` is listened to.
2. Subscribe to `_gateway.events` with an `onError` handler that logs
   (`debugPrint`) and marks the controller inactive rather than throwing.

`setActive(false)`: cancels the subscription (alone sufficient to release
the Android wake lock / disable iOS monitoring, per the native
implementations above) and calls `setScreenOffEnabled(false)` for
symmetry. Redundant calls with the same target value are no-ops — callers
don't need to track their own current-state.

**Wiring into `CallView`** (`lib/features/call/presentation/views/call_view.dart`):
- `initState()`: `_proximityController = ProximityScreenController(getIt<ProximitySensorGateway>())`.
- `_onViewModelChanged()`: compute
  `final shouldBeActive = state == PhoneCallState.connected && viewModel.isVoiceOnly && !viewModel.isSpeakerOn;`
  and call `_proximityController.setActive(shouldBeActive)`. This method
  already runs on every `CallViewModel` change (including
  `toggleSpeaker()`, which already calls `notifyListeners()`), so no new
  listener wiring is needed.
- `dispose()`: `_proximityController.dispose()`, alongside the existing
  `_audioPlayer.dispose()` / `_pulseController.dispose()` calls.
- `onNewReinvite`'s video-upgrade path (`call_view.dart:804-835`) currently
  does `setState(() => widget.call.voiceOnly = false)` on accept, which
  updates the View's own local state but does not itself call
  `_viewModel.notifyListeners()`. Confirm during implementation whether
  `_isVoiceOnly` on the ViewModel is updated through some other path when
  this happens (it is read from `viewModel.isVoiceOnly`, not
  `widget.call.voiceOnly`, in the `shouldBeActive` check) — if not, this
  needs a small additive fix so the video-upgrade case correctly
  deactivates proximity. Flagged here as a known open question for the
  implementation plan, not a blocker to this design.

No changes to `CallViewModel`, `SipCallManager`, `main.dart`, or any
balance-auto-refresh file — this is fully additive and isolated to the
call screen.

## Data flow & error handling

- Normal path: call connects (voice-only, not on speaker) →
  `_onViewModelChanged()` computes `shouldBeActive = true` →
  `ProximityScreenController.setActive(true)` → wake lock/monitoring
  enabled → screen dims when covered, restores when uncovered.
- Speaker toggled on mid-call: `toggleSpeaker()` → `notifyListeners()` →
  `_onViewModelChanged()` recomputes `shouldBeActive = false` →
  `setActive(false)` → screen restores immediately.
- Call ends: `phoneState` leaves `connected` → same recompute → `setActive(false)`
  → screen restores before the 2-second end-screen timer shows the
  terminal UI.
- Sensor unavailable or stream error: `onError` on the subscription marks
  the controller inactive and logs — the call is completely unaffected,
  the screen just never turns off.
- Widget disposed unexpectedly: `dispose()` unconditionally deactivates, so
  no wake lock/monitoring survives the `CallView`.

## Testing

- `ProximityScreenController` unit tests using a hand-rolled
  `FakeProximitySensorGateway` (a real fake, not a mock, matching this
  session's established pattern from `fake_async`/pure-function testing):
  - `setActive(true)` calls `setScreenOffEnabled(true)` before subscribing
    to `events` (order matters for the Android wake-lock quirk).
  - `setActive(false)` cancels the subscription.
  - Redundant `setActive` calls with the same value do not re-invoke the
    gateway.
  - A stream error transitions `isActive` to `false` without throwing.
  - `dispose()` is safe to call whether or not the controller was ever
    activated.
- No existing widget tests exercise `CallView` (verified: none under
  `test/`), so no regression risk there; a full `CallView` widget test
  harness is out of scope to newly build for this feature.
- Manual verification pass on a real device (same "needs real hardware,
  environment-blocked otherwise" precedent as the balance auto-refresh
  plan's Task 7): place a call, connect, cover the sensor → screen dims;
  uncover → screen restores; toggle speaker while covered → screen
  restores immediately; end the call while covered → screen restores
  within the 2s end-screen window; repeat for a device with the app
  backgrounded/foregrounded mid-call if practical.
