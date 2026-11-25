import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/managers/call_activity.dart';
import 'package:mvvm_sip_demo/core/managers/emergency_call_failures.dart';
import 'package:mvvm_sip_demo/core/managers/sip_call_manager.dart';
import 'package:mvvm_sip_demo/core/services/balance_refresh_coordinator.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:sip_ua/sip_ua.dart';
// ignore: implementation_imports
import 'package:sip_ua/src/name_addr_header.dart' show NameAddrHeader;
// ignore: implementation_imports
import 'package:sip_ua/src/rtc_session.dart' show RTCSession;

/// An RTCSession whose identity and direction look like sip_ua's: the
/// remote identity is the To (outgoing) or From (incoming) header.
class _FakeSession implements RTCSession {
  _FakeSession(this.user, this._direction);

  final String user;
  final Direction _direction;

  @override
  // ignore: non_constant_identifier_names
  NameAddrHeader? get remote_identity =>
      NameAddrHeader(URI('sip', user, 'sip.example.com'), null);

  @override
  Direction? get direction => _direction;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeDialpad implements DialpadViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Call _call(String id, String user, {Direction direction = Direction.outgoing}) =>
    Call(id, _FakeSession(user, direction), CallStateEnum.CALL_INITIATION,
        true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmergencyCallFailures', () {
    test('report keeps the latest number; take returns and clears it', () {
      final f = EmergencyCallFailures();
      expect(f.take(), isNull);
      f.report('999');
      f.report('112');
      expect(f.value, '112');
      expect(f.take(), '112');
      expect(f.value, isNull);
      expect(f.take(), isNull);
    });
  });

  group('SipCallManager reports failed emergency calls', () {
    late SipCallManager manager;
    late EmergencyCallFailures failures;

    setUp(() {
      failures = EmergencyCallFailures();
      manager = SipCallManager(
        SIPUAHelper(),
        GlobalKey<NavigatorState>(),
        _FakeDialpad(),
        BalanceRefreshCoordinator(
          refreshAccountSummary: () async => true,
          refreshDialpad: () async => true,
          showRetryingNotice: () {},
        ),
        callActivity: CallActivity(),
        emergencyCallFailures: failures,
      );
    });

    tearDown(() => manager.dispose());

    void run(Call call, List<CallStateEnum> states) {
      for (final s in states) {
        manager.callStateChanged(call, CallState(s));
      }
    }

    test('outgoing emergency call that fails', () {
      run(_call('c1', '999'),
          [CallStateEnum.CALL_INITIATION, CallStateEnum.FAILED]);
      expect(failures.value, '999');
    });

    test('outgoing emergency call that ends without connecting', () {
      run(_call('c1', '112'), [
        CallStateEnum.CALL_INITIATION,
        CallStateEnum.PROGRESS,
        CallStateEnum.ENDED,
      ]);
      expect(failures.value, '112');
    });

    test('outgoing emergency call that ends after connecting is not reported',
        () {
      run(_call('c1', '999'), [
        CallStateEnum.CALL_INITIATION,
        CallStateEnum.CONFIRMED,
        CallStateEnum.ENDED,
      ]);
      expect(failures.value, isNull);
    });

    test('incoming call from an emergency number that fails is not reported',
        () {
      run(_call('c1', '999', direction: Direction.incoming),
          [CallStateEnum.CALL_INITIATION, CallStateEnum.FAILED]);
      expect(failures.value, isNull);
    });

    test('outgoing non emergency call that fails is not reported', () {
      run(_call('c1', '0771234567'),
          [CallStateEnum.CALL_INITIATION, CallStateEnum.FAILED]);
      expect(failures.value, isNull);
    });
  });
}
