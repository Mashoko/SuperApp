import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_service.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_controller.dart';

KycStatus _status(String status, {bool launched = true}) =>
    KycStatus.fromJson({
      'status': status,
      'underlyingStatus': status,
      'launched': launched,
    });

class _FakeService implements KycService {
  int calls = 0;
  Completer<KycStatus>? gate;
  Object? failWith;
  KycStatus next = _status('IN_PROGRESS');

  @override
  Future<KycStatus> getStatus() async {
    calls++;
    if (gate != null) return gate!.future;
    if (failWith != null) throw failWith!;
    return next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeService service;
  late KycStatusController controller;

  setUp(() {
    service = _FakeService();
    controller = KycStatusController(service);
  });
  tearDown(() => controller.dispose());

  test('refresh populates status', () async {
    await controller.refresh();
    expect(controller.status?.status, 'IN_PROGRESS');
    expect(controller.launched, isTrue);
    expect(controller.loading, isFalse);
    expect(controller.error, isNull);
  });

  test('concurrent refreshes make one call', () async {
    service.gate = Completer<KycStatus>();
    final a = controller.refresh();
    final b = controller.refresh();
    service.gate!.complete(_status('APPROVED'));
    await Future.wait([a, b]);
    expect(service.calls, 1);
  });

  test('401 clears state', () async {
    await controller.refresh();
    service.failWith = KycApiException(401, 'Unauthorized');
    await controller.refresh();
    expect(controller.status, isNull);
    expect(controller.error, isNull);
    expect(controller.isRestricted, isFalse);
  });

  test('markRestricted flips before refresh completes and is idempotent',
      () async {
    service.gate = Completer<KycStatus>();
    controller.markRestricted();
    expect(controller.isRestricted, isTrue);
    controller.markRestricted();
    controller.markRestricted();
    expect(service.calls, 1);
    service.gate!.complete(_status('RESTRICTED'));
    await controller.refresh();
    expect(controller.isRestricted, isTrue);
  });

  test('successful non-restricted refresh clears the local flag', () async {
    controller.markRestricted();
    await controller.refresh();
    expect(controller.isRestricted, isFalse);
  });

  test('errors keep the last good status and set error', () async {
    await controller.refresh();
    service.failWith = KycApiException(500, 'Server is down');
    await controller.refresh();
    expect(controller.status?.status, 'IN_PROGRESS');
    expect(controller.error, 'Server is down');
  });

  test('resume triggers refresh', () async {
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(service.calls, 1);
  });

  test('timer refreshes every 30 minutes while resumed, stops when paused', () {
    fakeAsync((async) {
      final c = KycStatusController(service);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(service.calls, 1);
      async.elapse(const Duration(minutes: 30));
      expect(service.calls, 2);
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(minutes: 90));
      expect(service.calls, 2);
      c.dispose();
    });
  });
}
