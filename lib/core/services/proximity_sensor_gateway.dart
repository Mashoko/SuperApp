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
