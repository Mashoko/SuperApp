import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/managers/call_activity.dart';
import 'package:mvvm_sip_demo/core/managers/sip_call_manager.dart';
import 'package:mvvm_sip_demo/core/services/balance_refresh_coordinator.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:sip_ua/sip_ua.dart';
// ignore: implementation_imports
import 'package:sip_ua/src/rtc_session.dart' show RTCSession;

class _FakeSession implements RTCSession {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeDialpad implements DialpadViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Call _call(String id) =>
    Call(id, _FakeSession(), CallStateEnum.CALL_INITIATION, true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallActivity', () {
    test('active from call start until the call and its screen are gone', () {
      final a = CallActivity();
      expect(a.value, isFalse);
      a.callStarted('c1');
      expect(a.value, isTrue);
      a.viewOpened();
      a.callFinished('c1');
      expect(a.value, isTrue, reason: 'the end screen is still showing');
      a.viewClosed();
      expect(a.value, isFalse);
    });

    test('ends without a screen', () {
      final a = CallActivity()..callStarted('c1');
      a.callFinished('c1');
      expect(a.value, isFalse);
    });

    test('closing the call screen clears calls that never reported an end', () {
      final a = CallActivity()
        ..callStarted('c1')
        ..viewOpened();
      a.viewClosed();
      expect(a.value, isFalse);
    });

    test('two calls: active until both end', () {
      final a = CallActivity()
        ..callStarted('c1')
        ..callStarted('c2');
      a.callFinished('c1');
      expect(a.value, isTrue);
      a.callFinished('c2');
      expect(a.value, isFalse);
    });
  });

  group('SipCallManager', () {
    late SIPUAHelper helper;
    late CallActivity activity;
    late SipCallManager manager;

    setUp(() {
      helper = SIPUAHelper();
      activity = CallActivity();
      manager = SipCallManager(
        helper,
        GlobalKey<NavigatorState>(),
        _FakeDialpad(),
        BalanceRefreshCoordinator(
          refreshAccountSummary: () async => true,
          refreshDialpad: () async => true,
          showRetryingNotice: () {},
        ),
        callActivity: activity,
      );
    });

    tearDown(() => manager.dispose());

    for (final end in [CallStateEnum.ENDED, CallStateEnum.FAILED]) {
      test('CALL_INITIATION sets callActive, $end clears it', () {
        final call = _call('c1');
        manager.callStateChanged(
            call, CallState(CallStateEnum.CALL_INITIATION));
        expect(activity.value, isTrue);
        manager.callStateChanged(call, CallState(end));
        expect(activity.value, isFalse);
      });
    }
  });
}
