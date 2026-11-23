import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_controller.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/widgets/kyc_banner.dart';
import 'package:provider/provider.dart';

import 'kyc_test_fakes.dart';

const _deadline = '2026-12-23T12:00:00Z';

void main() {
  late FakeKycController controller;

  // Built outside the test's fake-async zone so its poll timer is not
  // reported as pending.
  setUp(() => controller = FakeKycController(null));
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, KycStatus? status,
      {Size size = const Size(375, 800), bool dark = false}) async {
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
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(children: [KycBanner(), Text('Home content')]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder bannerText() => find.descendant(
      of: find.byType(KycBanner), matching: find.byType(Text));

  group('hidden', () {
    testWidgets('while the status is unknown', (tester) async {
      await pump(tester, null);
      expect(bannerText(), findsNothing);
      expect(find.text('Home content'), findsOneWidget);
    });

    testWidgets('when not launched', (tester) async {
      await pump(tester,
          kycStatus(status: 'NOT_STARTED', launched: false, deadline: _deadline));
      expect(bannerText(), findsNothing);
    });

    for (final s in ['APPROVED', 'PENDING_REVIEW', 'RESTRICTED']) {
      testWidgets('when $s', (tester) async {
        await pump(tester, kycStatus(status: s, deadline: _deadline));
        expect(bannerText(), findsNothing);
      });
    }
  });

  const cases = {
    'NOT_STARTED': ('Verify your number before 23 December 2026.', 'Continue'),
    'IN_PROGRESS': ('Verify your number before 23 December 2026.', 'Continue'),
    'REJECTED': ('Your KYC needs attention.', 'Review'),
    'REQUIRES_CORRECTION': ('Your KYC needs attention.', 'Review'),
    'EXPIRED': ('Please renew your KYC.', 'Renew'),
  };

  for (final c in cases.entries) {
    testWidgets('${c.key} shows "${c.value.$1}" with ${c.value.$2}',
        (tester) async {
      await pump(tester, kycStatus(status: c.key, deadline: _deadline));
      expect(find.text(c.value.$1), findsOneWidget);
      expect(find.widgetWithText(TextButton, c.value.$2), findsOneWidget);
      expect(
          tester
              .getSize(find.widgetWithText(TextButton, c.value.$2))
              .height,
          greaterThanOrEqualTo(44));
    });
  }

  testWidgets('hairline border, no coloured tile', (tester) async {
    await pump(tester, kycStatus(status: 'IN_PROGRESS', deadline: _deadline));
    final box = tester
        .widgetList<Container>(find.descendant(
            of: find.byType(KycBanner), matching: find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .single;
    expect((box.border as Border).top.width, 1);
    expect(box.boxShadow, isNull);
    expect(box.gradient, isNull);
    expect(box.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('the action opens the status page', (tester) async {
    await pump(tester, kycStatus(status: 'EXPIRED'));
    await tester.tap(find.widgetWithText(TextButton, 'Renew'));
    await tester.pumpAndSettle();
    expect(find.byType(KycStatusView), findsOneWidget);
  });

  testWidgets('hides once the status becomes approved', (tester) async {
    await pump(tester, kycStatus(status: 'IN_PROGRESS', deadline: _deadline));
    expect(bannerText(), findsWidgets);
    controller.status = kycStatus(status: 'APPROVED');
    controller.notifyListeners();
    await tester.pump();
    expect(bannerText(), findsNothing);
  });

  for (final size in const [Size(375, 700), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('no overflow at ${size.width.toInt()} wide', (tester) async {
      await pump(tester, kycStatus(status: 'IN_PROGRESS', deadline: _deadline),
          size: size);
      expect(tester.takeException(), isNull);
    });
  }
}
