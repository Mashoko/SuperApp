import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_service.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_notifications_view.dart';

import 'kyc_test_fakes.dart';

const unreadDot = ValueKey('kyc-unread-dot');

void main() {
  late FakeKycService service;

  setUp(() => service = FakeKycService());

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(375, 800), bool dark = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          useMaterial3: true,
          brightness: dark ? Brightness.dark : Brightness.light),
      home: KycNotificationsView(service: service),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a spinner while loading', (tester) async {
    service.listGate = Completer<void>();
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(home: KycNotificationsView(service: service)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.listGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('empty list says "No updates yet."', (tester) async {
    await pump(tester);
    expect(find.text('No updates yet.'), findsOneWidget);
  });

  testWidgets('error shows the message and retries', (tester) async {
    service.listError = KycApiException(0, 'You are offline.');
    await pump(tester);
    expect(find.text('You are offline.'), findsOneWidget);
    service.listError = null;
    service.notificationPages[1] = (
      items: [kycNote('a', title: 'Details received')],
      unread: 1,
      totalPages: 1,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Details received'), findsOneWidget);
    expect(service.listCalls, [1, 1]);
  });

  testWidgets('lists items with local dates and an unread dot',
      (tester) async {
    service.notificationPages[1] = (
      items: [
        kycNote('a', title: 'Needs a correction'),
        kycNote('b', title: 'Details received', read: true),
      ],
      unread: 1,
      totalPages: 1,
    );
    await pump(tester);
    expect(find.text('Needs a correction'), findsOneWidget);
    expect(find.text('Details received'), findsOneWidget);
    expect(find.text('20 November 2026'), findsNWidgets(2));
    expect(find.byKey(unreadDot), findsOneWidget);
  });

  testWidgets('tapping an unread item marks it read', (tester) async {
    service.notificationPages[1] =
        (items: [kycNote('a', title: 'Needs a correction')], unread: 1, totalPages: 1);
    await pump(tester);
    await tester.tap(find.text('Needs a correction'));
    await tester.pumpAndSettle();
    expect(service.markReadCalls, ['a']);
    expect(find.byKey(unreadDot), findsNothing);
    await tester.tap(find.text('Needs a correction'));
    await tester.pumpAndSettle();
    expect(service.markReadCalls, ['a'], reason: 'already read');
  });

  testWidgets('a failed mark-read puts the dot back', (tester) async {
    service.notificationPages[1] =
        (items: [kycNote('a', title: 'Needs a correction')], unread: 1, totalPages: 1);
    service.markReadError = KycApiException(0, 'You are offline.');
    service.markReadGate = Completer<void>();
    await pump(tester);
    await tester.tap(find.text('Needs a correction'));
    await tester.pump();
    expect(find.byKey(unreadDot), findsNothing, reason: 'optimistic');
    service.markReadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(unreadDot), findsOneWidget);
  });

  testWidgets('loads the next page at the end of the list', (tester) async {
    service.notificationPages[1] = (
      items: [for (var i = 0; i < 12; i++) kycNote('p1-$i', title: 'First $i')],
      unread: 0,
      totalPages: 2,
    );
    service.notificationPages[2] =
        (items: [kycNote('p2', title: 'Last one')], unread: 0, totalPages: 2);
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Last one'), 300);
    expect(find.text('Last one'), findsOneWidget);
    expect(service.listCalls, [1, 2]);
  });

  testWidgets('a failed next page offers a retry', (tester) async {
    service.notificationPages[1] = (
      items: [kycNote('a', title: 'First')],
      unread: 0,
      totalPages: 2,
    );
    service.notificationPages[2] =
        (items: [kycNote('b', title: 'Second')], unread: 0, totalPages: 2);
    service.listGate = null;
    await pump(tester);
    // Page 2 loaded automatically; make a fresh view whose page 2 fails.
    service.listCalls.clear();
    await tester.pumpWidget(const SizedBox());
    final failing = _FailOnPage2(service);
    await tester.pumpWidget(
        MaterialApp(home: KycNotificationsView(service: failing)));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Try again'), findsOneWidget);
    failing.fail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the first page', (tester) async {
    service.notificationPages[1] =
        (items: [kycNote('a', title: 'First')], unread: 0, totalPages: 1);
    await pump(tester);
    await tester.fling(find.text('First'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(service.listCalls, [1, 1]);
  });

  for (final size in const [Size(375, 700), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('no overflow at ${size.width.toInt()} wide', (tester) async {
      service.notificationPages[1] = (
        items: [
          kycNote('a',
              title: 'Your verification needs a correction before the deadline',
              body:
                  'Please upload a clearer proof of residence dated within the last three months.'),
        ],
        unread: 1,
        totalPages: 1,
      );
      await pump(tester, size: size, dark: true);
      expect(tester.takeException(), isNull);
    });
  }
}

class _FailOnPage2 implements KycService {
  _FailOnPage2(this._inner);

  final FakeKycService _inner;
  bool fail = true;

  @override
  Future<KycNotificationPage> listNotifications({int page = 1}) {
    if (page == 2 && fail) {
      return Future.error(KycApiException(0, 'You are offline.'));
    }
    return _inner.listNotifications(page: page);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
