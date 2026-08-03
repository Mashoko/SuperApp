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
