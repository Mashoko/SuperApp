import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_controller.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/widgets/kyc_reminder_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kyc_test_fakes.dart';

KycNotification _note(String id, String kind,
        {bool read = false, int day = 20, String? title}) =>
    KycNotification(
      id: id,
      kind: kind,
      title: title ?? 'Reminder $id',
      body: 'Verify your number before 23 December 2026.',
      createdAt: DateTime.utc(2026, 11, day, 10),
      readAt: read ? DateTime.utc(2026, 11, 21) : null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeKycService service;
  late FakeKycController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetKycReminderSessionForTest();
    service = FakeKycService();
    controller = FakeKycController(kycStatus(status: 'IN_PROGRESS'));
  });

  tearDown(() => controller.dispose());

  void serve(List<KycNotification> items) {
    service.notificationPages[1] =
        (items: items, unread: items.length, totalPages: 1);
  }

  Future<void> pumpHome(WidgetTester tester,
      {Size size = const Size(375, 800), bool dark = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<KycStatusController>.value(
      value: controller,
      child: MaterialApp(
        theme: ThemeData(
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light),
        home: KycReminderHost(
          service: service,
          child: const Scaffold(body: Center(child: Text('Home'))),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a new reminder once, Later closes and persists',
      (tester) async {
    serve([_note('n1', 'REMINDER')]);
    await pumpHome(tester);
    expect(find.text('Reminder n1'), findsOneWidget);
    expect(find.text('Verify your number before 23 December 2026.'),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Later'));
    await tester.pumpAndSettle();
    expect(find.text('Reminder n1'), findsNothing);
    expect(service.markReadCalls, ['n1']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(kycDismissedNotificationsKey), ['n1']);

    // A new status in the same session does not show it again.
    controller.next = kycStatus(status: 'IN_PROGRESS', progress: 10);
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Reminder n1'), findsNothing);

    // Nor does a new app session: the id is persisted.
    resetKycReminderSessionForTest();
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester);
    expect(find.text('Reminder n1'), findsNothing);
  });

  testWidgets('Continue opens the status page and marks read', (tester) async {
    serve([_note('n2', 'WARNING')]);
    await pumpHome(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(KycStatusView), findsOneWidget);
    expect(service.markReadCalls, ['n2']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(kycDismissedNotificationsKey), ['n2']);
  });

  testWidgets('picks the newest unread eligible notification', (tester) async {
    serve([
      _note('old', 'NUDGE_1', day: 1),
      _note('submitted', 'SUBMITTED', day: 22),
      _note('read', 'CORRECTION_REQUESTED', read: true, day: 21),
      _note('stage', 'REMINDER_3', day: 15),
    ]);
    await pumpHome(tester);
    expect(find.text('Reminder stage'), findsOneWidget);
  });

  testWidgets('ignores ineligible kinds', (tester) async {
    serve([_note('s', 'SUBMITTED'), _note('a', 'APPROVED')]);
    await pumpHome(tester);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('a mark-read failure still closes and records the dismissal',
      (tester) async {
    service.markReadError = Exception('offline');
    serve([_note('n3', 'EXPIRED')]);
    await pumpHome(tester);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(kycDismissedNotificationsKey), ['n3']);
  });

  testWidgets('keeps only the last 50 dismissed ids', (tester) async {
    SharedPreferences.setMockInitialValues({
      kycDismissedNotificationsKey: [for (var i = 0; i < 50; i++) 'x$i'],
    });
    serve([_note('n4', 'REJECTED')]);
    await pumpHome(tester);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(kycDismissedNotificationsKey)!;
    expect(ids.length, 50);
    expect(ids.first, 'x1');
    expect(ids.last, 'n4');
  });

  for (final (label, status) in [
    ('approved', kycStatus(status: 'APPROVED')),
    ('pending review', kycStatus(status: 'PENDING_REVIEW')),
    ('restricted', kycStatus(status: 'RESTRICTED')),
    ('not launched', kycStatus(status: 'IN_PROGRESS', launched: false)),
  ]) {
    testWidgets('not shown when $label', (tester) async {
      controller.status = status;
      serve([_note('n5', 'REMINDER')]);
      await pumpHome(tester);
      expect(find.byType(BottomSheet), findsNothing);
      expect(service.listCalls, isEmpty);
    });
  }

  testWidgets('waits for the status, then shows', (tester) async {
    controller.status = null;
    serve([_note('n6', 'NUDGE_2')]);
    await pumpHome(tester);
    expect(find.byType(BottomSheet), findsNothing);
    controller.next = kycStatus(status: 'NOT_STARTED');
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Reminder n6'), findsOneWidget);
  });

  testWidgets('not shown over another screen, shown back on home',
      (tester) async {
    controller.status = null;
    serve([_note('n8', 'REMINDER')]);
    await pumpHome(tester);
    final nav = Navigator.of(tester.element(find.text('Home')));
    unawaited(nav.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Call screen')))));
    await tester.pumpAndSettle();
    controller.next = kycStatus(status: 'IN_PROGRESS');
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    nav.pop();
    await tester.pumpAndSettle();
    controller.next = kycStatus(status: 'IN_PROGRESS', progress: 20);
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Reminder n8'), findsOneWidget);
  });

  for (final size in const [Size(375, 667), Size(768, 1024), Size(1280, 800)]) {
    for (final dark in [false, true]) {
      testWidgets(
          'sheet fits at ${size.width.toInt()} wide${dark ? ' (dark)' : ''}',
          (tester) async {
        final handle = tester.ensureSemantics();
        serve([
          _note('n7', 'REMINDER',
              title: 'Verify your number. Your account will be limited soon if '
                  'we cannot confirm who owns it.'),
        ]);
        await pumpHome(tester, size: size, dark: dark);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.widgetWithText(TextButton, 'Later')).height,
            greaterThanOrEqualTo(44));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
    }
  }
}
