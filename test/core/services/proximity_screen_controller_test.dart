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
