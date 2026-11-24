import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart' show getIt;
import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_service.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_form_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_notifications_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_controller.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_view.dart';
import 'package:provider/provider.dart';

import 'kyc_test_fakes.dart';

const _labels = {
  'NOT_STARTED': 'Not started',
  'IN_PROGRESS': 'In progress',
  'PENDING_REVIEW': 'Under review',
  'APPROVED': 'Verified',
  'REJECTED': 'Not approved',
  'REQUIRES_CORRECTION': 'Needs a correction',
  'EXPIRED': 'Expired',
  'RESTRICTED': 'Action needed',
};

void main() {
  late FakeKycController controller;

  // Built outside the test's fake-async zone so its poll timer is not
  // reported as pending.
  setUp(() => controller = FakeKycController(null));
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, KycStatus? status,
      {Size size = const Size(375, 800), bool dark = false, bool settle = true}) async {
    controller.status = status;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<KycStatusController>.value(
      value: controller,
      child: MaterialApp(
        theme: ThemeData(
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light),
        home: const KycStatusView(),
      ),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  for (final entry in _labels.entries) {
    testWidgets('${entry.key} renders "${entry.value}"', (tester) async {
      await pump(tester, kycStatus(status: entry.key));
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('refreshes the controller on open', (tester) async {
    await pump(tester, kycStatus());
    expect(controller.refreshCalls, 1);
  });

  testWidgets('loading while there is no status yet', (tester) async {
    await pump(tester, null, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error without a status shows the message and retries',
      (tester) async {
    await pump(tester, null, settle: false);
    controller.error = 'You are offline.';
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('You are offline.'), findsOneWidget);
    final before = controller.refreshCalls;
    controller.next = kycStatus(status: 'IN_PROGRESS');
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();
    expect(controller.refreshCalls, before + 1);
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('a failed refresh over a known status keeps it with a notice',
      (tester) async {
    await pump(tester, kycStatus(status: 'IN_PROGRESS'));
    controller.error = 'You are offline.';
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('You are offline.'), findsOneWidget);
  });

  testWidgets('not launched shows the closed message and no button',
      (tester) async {
    await pump(tester, kycStatus(launched: false, status: 'NOT_STARTED'));
    expect(find.text('Verification is not open yet.'), findsOneWidget);
    expect(find.text('Continue verification'), findsNothing);
  });

  testWidgets('progress, deadline and outstanding items with labels',
      (tester) async {
    await pump(
        tester,
        kycStatus(
          status: 'IN_PROGRESS',
          progress: 60,
          deadline: '2026-12-23T12:00:00Z',
          outstanding: ['personal.firstName', 'documents.id_front'],
        ));
    expect(find.text('60%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Complete by 23 December 2026'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('National ID, front'), findsOneWidget);
    expect(find.text('personal.firstName'), findsNothing);
  });

  for (final s in ['APPROVED', 'PENDING_REVIEW']) {
    testWidgets('$s hides the deadline and the button', (tester) async {
      await pump(tester,
          kycStatus(status: s, deadline: '2026-12-23T12:00:00Z', progress: 100));
      expect(find.textContaining('Complete by'), findsNothing);
      expect(find.text('Continue verification'), findsNothing);
    });
  }

  group('reviewer note', () {
    Future<void> pumpNote(WidgetTester tester, String status,
            [String? underlying]) =>
        pump(
            tester,
            kycStatus(
              status: status,
              underlyingStatus: underlying,
              rejectionReason: 'The photo is blurred.',
              correctionNotes: 'Add the back of your ID.',
            ));

    testWidgets('REJECTED shows only the rejection reason', (tester) async {
      await pumpNote(tester, 'REJECTED');
      expect(find.text('The photo is blurred.'), findsOneWidget);
      expect(find.text('Add the back of your ID.'), findsNothing);
    });

    testWidgets('REQUIRES_CORRECTION shows only the correction notes',
        (tester) async {
      await pumpNote(tester, 'REQUIRES_CORRECTION');
      expect(find.text('Add the back of your ID.'), findsOneWidget);
      expect(find.text('The photo is blurred.'), findsNothing);
    });

    testWidgets('uses the underlying status when restricted', (tester) async {
      await pumpNote(tester, 'RESTRICTED', 'REJECTED');
      expect(find.text('The photo is blurred.'), findsOneWidget);
      expect(find.text('Add the back of your ID.'), findsNothing);
    });

    testWidgets('IN_PROGRESS shows no note', (tester) async {
      await pumpNote(tester, 'IN_PROGRESS');
      expect(find.text('The photo is blurred.'), findsNothing);
      expect(find.text('Add the back of your ID.'), findsNothing);
    });
  });

  testWidgets('submission history lists each version with local dates',
      (tester) async {
    await pump(
        tester,
        kycStatus(status: 'REJECTED', history: [
          {
            'version': 1,
            'submittedAt': '2026-11-01T09:00:00Z',
            'decision': 'rejected',
            'decidedAt': '2026-11-03T09:00:00Z',
          },
          {
            'version': 2,
            'submittedAt': '2026-11-10T09:00:00Z',
            'decision': 'pending',
          },
        ]));
    await tester.scrollUntilVisible(find.text('Submission 2'), 200);
    expect(find.text('Submission 1'), findsOneWidget);
    expect(find.text('Submission 2'), findsOneWidget);
    expect(find.textContaining('1 November 2026'), findsOneWidget);
    expect(find.textContaining('3 November 2026'), findsOneWidget);
  });

  testWidgets('Continue verification opens the form, refreshes after pop',
      (tester) async {
    await pump(tester, kycStatus(status: 'IN_PROGRESS', draft: completeDraft));
    getIt.registerSingleton<KycService>(FakeKycService());
    getIt.registerSingleton<KycStatusController>(controller,
        dispose: (_) {});
    addTearDown(() {
      getIt.unregister<KycService>();
      getIt.unregister<KycStatusController>();
    });
    final before = controller.refreshCalls;
    await tester.tap(find.widgetWithText(FilledButton, 'Continue verification'));
    await tester.pumpAndSettle();
    expect(find.byType(KycFormView), findsOneWidget);
    Navigator.of(tester.element(find.byType(KycFormView))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(KycFormView), findsNothing);
    // One refresh from the form's own load, one after it closes.
    expect(controller.refreshCalls, greaterThanOrEqualTo(before + 2));
  });

  testWidgets('Updates opens the notifications list', (tester) async {
    await pump(tester, kycStatus(status: 'IN_PROGRESS'));
    getIt.registerSingleton<KycService>(FakeKycService());
    addTearDown(() => getIt.unregister<KycService>());
    await tester.scrollUntilVisible(find.text('Updates'), 200);
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    expect(find.byType(KycNotificationsView), findsOneWidget);
  });

  testWidgets('touch targets are at least 44 px', (tester) async {
    await pump(tester, kycStatus(status: 'IN_PROGRESS'));
    final button = tester
        .getSize(find.widgetWithText(FilledButton, 'Continue verification'));
    expect(button.height, greaterThanOrEqualTo(44));
    await tester.scrollUntilVisible(find.text('Updates'), 200);
    expect(tester.getSize(find.ancestor(
            of: find.text('Updates'), matching: find.byType(TextButton))).height,
        greaterThanOrEqualTo(44));
  });

  for (final size in const [Size(375, 700), Size(768, 1024), Size(1280, 800)]) {
    for (final dark in [false, true]) {
      testWidgets(
          'no overflow at ${size.width.toInt()} wide${dark ? ' (dark)' : ''}',
          (tester) async {
        await pump(
            tester,
            kycStatus(
              status: 'RESTRICTED',
              underlyingStatus: 'REQUIRES_CORRECTION',
              progress: 45,
              deadline: '2026-12-23T12:00:00Z',
              outstanding: [
                'personal.firstName',
                'address.city',
                'documents.proof_of_residence',
              ],
              correctionNotes:
                  'Please upload a clearer proof of residence dated within the last three months.',
              history: [
                {
                  'version': 1,
                  'submittedAt': '2026-11-01T09:00:00Z',
                  'decision': 'correction_requested',
                  'decidedAt': '2026-11-03T09:00:00Z',
                  'reason': 'Proof of residence is older than three months.',
                },
              ],
            ),
            size: size,
            dark: dark);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
