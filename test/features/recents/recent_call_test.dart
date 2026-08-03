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
