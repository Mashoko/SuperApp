import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_service.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_form_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_gate.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_controller.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/mandatory_kyc_view.dart';
import 'package:provider/provider.dart';

import 'kyc_test_fakes.dart';

KycStatus _restricted(
        {List<String> outstanding = const [
          'personal.firstName',
          'documents.id_front',
        ]}) =>
    kycStatus(
      status: 'RESTRICTED',
      underlyingStatus: 'IN_PROGRESS',
      outstanding: outstanding,
      progress: 40,
    );

/// The app underneath the gate: a counter so we can tell that taps are
/// blocked and that its state survives the gate.
class _AppHome extends StatefulWidget {
  const _AppHome();

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => setState(() => taps++),
            child: Text('App button $taps'),
          ),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GlobalKey<NavigatorState> rootKey;
  late int signOuts;
  late ValueNotifier<bool> callActive;

  setUp(() {
    rootKey = GlobalKey<NavigatorState>();
    signOuts = 0;
    callActive = ValueNotifier<bool>(false);
  });

  Future<void> pumpGate(
    WidgetTester tester,
    KycStatusController controller, {
    Size size = const Size(375, 800),
    bool dark = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<KycStatusController>.value(
      value: controller,
      child: MaterialApp(
        navigatorKey: rootKey,
        theme: ThemeData(
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light),
        home: const _AppHome(),
        builder: (context, child) => KycGate(
          navigatorKey: rootKey,
          callActive: callActive,
          supportBuilder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Support page')),
          ),
          onSignOut: () async {
            signOuts++;
            controller.clear();
          },
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ));
    if (settle) await tester.pumpAndSettle();
  }

  group('with a fake controller', () {
    late FakeKycController controller;

    // Built outside fake-async so its poll timer is not reported as pending.
    setUp(() => controller = FakeKycController(_restricted()));
    tearDown(() => controller.dispose());

    testWidgets('not launched: no gate, app usable', (tester) async {
      controller.status = kycStatus(status: 'RESTRICTED', launched: false);
      await pumpGate(tester, controller);
      expect(find.byType(MandatoryKycView), findsNothing);
      await tester.tap(find.text('App button 0'));
      await tester.pump();
      expect(find.text('App button 1'), findsOneWidget);
    });

    testWidgets('not restricted: no gate', (tester) async {
      controller.status = kycStatus(status: 'IN_PROGRESS');
      await pumpGate(tester, controller);
      expect(find.byType(MandatoryKycView), findsNothing);
    });

    testWidgets('restricted: mandatory view with exact copy, app blocked',
        (tester) async {
      controller.status = _restricted();
      await pumpGate(tester, controller);
      expect(find.byType(MandatoryKycView), findsOneWidget);
      expect(find.text('Complete your KYC verification'), findsOneWidget);
      expect(
          find.text(
              'Your account needs verification to keep using calls, shopping, payments and posts.'),
          findsOneWidget);
      expect(
          find.text(
              'POTRAZ requires us to confirm who owns each number. Emergency calls still work.'),
          findsOneWidget);
      expect(find.text('First name'), findsOneWidget);
      expect(find.text('National ID, front'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('About 5 minutes'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Complete KYC now'),
          findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget,
          reason: 'one primary button');
      expect(
          find.widgetWithText(TextButton, 'Contact support'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sign out'), findsOneWidget);

      // The app underneath stays mounted but cannot be tapped.
      expect(find.text('App button 0', skipOffstage: false), findsOneWidget);
      await tester.tap(find.text('App button 0'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('App button 0', skipOffstage: false), findsOneWidget);
    });

    testWidgets('restricted: screen readers cannot reach the app',
        (tester) async {
      final handle = tester.ensureSemantics();
      controller.status = _restricted();
      await pumpGate(tester, controller);
      expect(find.bySemanticsLabel('App button 0'), findsNothing);
      expect(find.bySemanticsLabel('Complete KYC now'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('system back never reveals or pops the app', (tester) async {
      controller.status = kycStatus(status: 'IN_PROGRESS');
      await pumpGate(tester, controller);
      rootKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Detail page'))));
      await tester.pumpAndSettle();

      controller.status = _restricted();
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsOneWidget);

      // Back inside the gate pops the gate's own routes first.
      await tester.tap(find.text('Contact support'));
      await tester.pumpAndSettle();
      expect(find.text('Support page'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Support page'), findsNothing);
      expect(find.byType(MandatoryKycView), findsOneWidget);

      controller.status = kycStatus(status: 'PENDING_REVIEW');
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);
      expect(find.text('Detail page'), findsOneWidget,
          reason: 'the app route under the gate was not popped');
      // And back works normally again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsNothing);
      expect(find.text('App button 0'), findsOneWidget);
    });

    testWidgets('an active call lifts the gate; the gate returns after it',
        (tester) async {
      controller.status = _restricted();
      await pumpGate(tester, controller);
      expect(find.byType(MandatoryKycView), findsOneWidget);

      // CALL_INITIATION: the call screen is pushed on the app navigator.
      callActive.value = true;
      rootKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => rootKey.currentState!.pop(),
                    child: const Text('Hang up'),
                  ),
                ),
              )));
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);
      // The call screen is visible and usable; back is not swallowed.
      await tester.tap(find.text('Hang up'));
      await tester.pumpAndSettle();
      expect(find.text('Hang up'), findsNothing);
      expect(find.byType(MandatoryKycView), findsNothing);

      callActive.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsOneWidget);
      // Back is blocked again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsOneWidget);
    });

    testWidgets('restriction arriving during a call does not cover it',
        (tester) async {
      controller.status = kycStatus(status: 'IN_PROGRESS');
      await pumpGate(tester, controller);
      callActive.value = true;
      rootKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Call screen'))));
      await tester.pumpAndSettle();

      controller.status = _restricted();
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);
      expect(find.text('Call screen'), findsOneWidget);
      // Back reaches the call screen's navigator as usual.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Call screen'), findsNothing);

      callActive.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsOneWidget);
    });

    testWidgets('Contact support opens help inside the gate', (tester) async {
      controller.status = _restricted();
      await pumpGate(tester, controller);
      await tester.tap(find.text('Contact support'));
      await tester.pumpAndSettle();
      expect(find.text('Support page'), findsOneWidget);
      final nav = Navigator.of(tester.element(find.text('Support page')));
      expect(identical(nav, rootKey.currentState), isFalse);
      // The page is not pushed on the app's navigator.
      expect(
          find.descendant(
              of: find.byType(_AppHome, skipOffstage: false),
              matching: find.text('Support page', skipOffstage: false)),
          findsNothing);
    });

    testWidgets('Sign out uses the logout path and leaves the gate',
        (tester) async {
      controller.status = _restricted();
      await pumpGate(tester, controller);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(signOuts, 1);
      expect(find.byType(MandatoryKycView), findsNothing);
    });

    testWidgets(
        'gate disappears after refresh with PENDING_REVIEW, app state kept',
        (tester) async {
      controller.status = kycStatus(status: 'IN_PROGRESS');
      await pumpGate(tester, controller);
      await tester.tap(find.text('App button 0'));
      await tester.pump();

      controller.status = _restricted();
      controller.notifyListeners();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contact support'));
      await tester.pumpAndSettle();

      controller.next = kycStatus(status: 'PENDING_REVIEW');
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);
      expect(find.text('Support page'), findsNothing,
          reason: 'routes inside the gate are discarded');
      expect(find.text('App button 1'), findsOneWidget);
      await tester.tap(find.text('App button 1'));
      await tester.pump();
      expect(find.text('App button 2'), findsOneWidget);
    });

    testWidgets('error with a cached status shows a notice and keeps actions',
        (tester) async {
      controller.status = _restricted();
      controller.error = 'You are offline.';
      await pumpGate(tester, controller);
      expect(find.text('You are offline.'), findsOneWidget);
      expect(find.text('Complete KYC now'), findsOneWidget);
    });

    testWidgets(
        'MandatoryKycView with no status: loading, then error and retry',
        (tester) async {
      controller.status = null;
      await tester.pumpWidget(ChangeNotifierProvider<KycStatusController>.value(
        value: controller,
        child: MaterialApp(
          home: MandatoryKycView(
              onCompleteNow: () {}, onContactSupport: () {}, onSignOut: () {}),
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      controller.error = 'You are offline.';
      controller.notifyListeners();
      await tester.pump();
      expect(find.text('You are offline.'), findsOneWidget);
      controller.failWith = null;
      controller.next = _restricted();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(controller.refreshCalls, 1);
      expect(find.text('Complete your KYC verification'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('tap targets, labels and contrast${dark ? ' (dark)' : ''}',
          (tester) async {
        final handle = tester.ensureSemantics();
        controller.status = _restricted();
        await pumpGate(tester, controller, dark: dark);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    for (final size in const [
      Size(375, 667),
      Size(768, 1024),
      Size(1280, 800)
    ]) {
      for (final dark in [false, true]) {
        testWidgets(
            'no overflow at ${size.width.toInt()} wide${dark ? ' (dark)' : ''}',
            (tester) async {
          controller.status = _restricted(outstanding: const [
            'personal.firstName',
            'personal.lastName',
            'personal.dateOfBirth',
            'address.line1',
            'identification.idNumber',
            'documents.id_front',
            'documents.id_back',
            'documents.proof_of_residence',
          ]);
          await pumpGate(tester, controller, size: size, dark: dark);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Sign out'), 200);
          expect(tester.takeException(), isNull);
          final button = tester
              .getSize(find.widgetWithText(FilledButton, 'Complete KYC now'));
          expect(button.width, lessThanOrEqualTo(640));
        });
      }
    }
  });

  group('with the real controller', () {
    late FakeKycService service;
    late KycStatusController controller;

    setUp(() {
      service = FakeKycService();
      controller = KycStatusController(service);
      getIt.registerSingleton<KycService>(service);
      getIt.registerSingleton<KycStatusController>(controller, dispose: (_) {});
    });

    tearDown(() {
      getIt.unregister<KycService>();
      getIt.unregister<KycStatusController>();
      controller.dispose();
    });

    testWidgets(
        'markRestricted, gate shows, back does nothing, submit lifts the gate',
        (tester) async {
      service.statusResult = kycStatus(status: 'IN_PROGRESS');
      await pumpGate(tester, controller);
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);

      // The server answers 403 KYC_REQUIRED; the status arrives later.
      service.statusGate = Completer<void>();
      service.statusResult = kycStatus(
        status: 'RESTRICTED',
        underlyingStatus: 'IN_PROGRESS',
        draft: completeDraft,
        documents: [docJson('id_front'), docJson('id_back')],
        progress: 90,
      );
      controller.markRestricted();
      await tester.pump();
      expect(tester.takeException(), isNull);
      service.statusGate!.complete();
      service.statusGate = null;
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsOneWidget);

      await tester.tap(find.text('Complete KYC now'));
      await tester.pumpAndSettle();
      expect(find.byType(KycFormView), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
      }
      service.statusResult = kycStatus(status: 'PENDING_REVIEW');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit for review'));
      await tester.pumpAndSettle();
      expect(service.submits, 1);
      expect(find.byType(MandatoryKycView), findsNothing);
      expect(find.byType(KycFormView), findsNothing);
      expect(find.text('App button 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
