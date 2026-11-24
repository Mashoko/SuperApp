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
  tearDown(() {
    // dispose is idempotent for our purposes: guard against double dispose
    try {
      controller.dispose();
    } catch (_) {}
  });

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
      addTearDown(c.dispose);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(service.calls, 1);
      async.elapse(const Duration(minutes: 30));
      expect(service.calls, 2);
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(minutes: 90));
      expect(service.calls, 2);
    });
  });

  test('controller built while binding is resumed polls without a resume event',
      () {
    // Avoid the setUp controller reacting to the lifecycle change.
    controller.dispose();
    TestWidgetsFlutterBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    fakeAsync((async) {
      final c = KycStatusController(service);
      addTearDown(c.dispose);
      expect(service.calls, 0);
      async.elapse(const Duration(minutes: 30));
      expect(service.calls, 1);
    });
  });

  test('clear during a pending refresh discards its result', () async {
    service.gate = Completer<KycStatus>();
    final pending = controller.refresh();
    controller.clear();
    service.gate!.complete(_status('APPROVED'));
    await pending;
    expect(controller.status, isNull);
  });

  test('refresh after clear issues a new call while the old one is pending',
      () async {
    service.gate = Completer<KycStatus>();
    final old = controller.refresh();
    controller.clear();
    final fresh = controller.refresh();
    expect(service.calls, 2);
    service.gate!.complete(_status('APPROVED'));
    await Future.wait([old, fresh]);
    expect(controller.status?.status, 'APPROVED');
  });

  test('markRestricted is not undone by an earlier stale refresh', () async {
    service.gate = Completer<KycStatus>();
    final stale = controller.refresh();
    controller.markRestricted();
    expect(service.calls, 2);
    service.gate!.complete(_status('IN_PROGRESS'));
    await stale;
    expect(controller.isRestricted, isTrue);
  });

  test('background refresh does not toggle loading once status is known',
      () async {
    await controller.refresh();
    service.gate = Completer<KycStatus>();
    final f = controller.refresh();
    expect(controller.loading, isFalse);
    service.gate!.complete(_status('IN_PROGRESS'));
    await f;
  });

  group('applySubmitted', () {
    test('marks the status PENDING_REVIEW and clears the restriction',
        () async {
      service.next = _status('RESTRICTED');
      await controller.refresh();
      controller.markRestricted();
      await Future<void>.delayed(Duration.zero);
      expect(controller.isRestricted, isTrue);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.applySubmitted();
      expect(controller.status!.status, 'PENDING_REVIEW');
      expect(controller.status!.underlyingStatus, 'PENDING_REVIEW');
      expect(controller.status!.isPendingReview, isTrue);
      expect(controller.status!.launched, isTrue, reason: 'other fields kept');
      expect(controller.isRestricted, isFalse);
      expect(notified, 1);
    });

    test('a failed refresh afterwards keeps PENDING_REVIEW', () async {
      service.next = _status('RESTRICTED');
      await controller.refresh();
      controller.applySubmitted();
      service.failWith = KycApiException(0, 'You are offline.');
      await controller.refresh();
      expect(controller.status!.status, 'PENDING_REVIEW');
      expect(controller.isRestricted, isFalse);
      expect(controller.error, 'You are offline.');
    });

    test('a later successful refresh overwrites it', () async {
      service.next = _status('RESTRICTED');
      await controller.refresh();
      controller.applySubmitted();
      service.next = _status('REQUIRES_CORRECTION');
      await controller.refresh();
      expect(controller.status!.status, 'REQUIRES_CORRECTION');
    });

    test('a refresh started before it cannot bring back the old status',
        () async {
      service.next = _status('RESTRICTED');
      await controller.refresh();
      service.gate = Completer<KycStatus>();
      final stale = controller.refresh();
      controller.applySubmitted();
      service.gate!.complete(_status('RESTRICTED'));
      await stale;
      expect(controller.status!.status, 'PENDING_REVIEW');
    });

    test('does nothing without a status', () {
      var notified = 0;
      controller.addListener(() => notified++);
      controller.applySubmitted();
      expect(controller.status, isNull);
      expect(notified, 0);
    });
  });
}
