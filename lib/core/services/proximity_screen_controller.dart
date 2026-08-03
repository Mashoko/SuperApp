import 'dart:async';

import 'package:flutter/foundation.dart';

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
      try {
        await _gateway.setScreenOffEnabled(true);
        _subscription = _gateway.events.listen(
          (_) {},
          onError: (Object _) {
            _isActive = false;
            _subscription?.cancel();
            _subscription = null;
            // Call setScreenOffEnabled(false) asynchronously; catch errors to avoid pollution
            _gateway.setScreenOffEnabled(false).catchError((e) {
              debugPrint('ProximityScreenController: Error disabling screen-off in stream error handler: $e');
            });
          },
        );
        _isActive = true;
      } catch (e) {
        debugPrint('ProximityScreenController: Error activating screen-off: $e');
        _isActive = false;
        _subscription?.cancel();
        _subscription = null;
      }
    } else {
      try {
        final subscription = _subscription;
        _subscription = null;
        await subscription?.cancel();
        await _gateway.setScreenOffEnabled(false);
        _isActive = false;
      } catch (e) {
        debugPrint('ProximityScreenController: Error deactivating screen-off: $e');
        _isActive = false;
        _subscription = null;
      }
    }
  }

  Future<void> dispose() => setActive(false);
}
