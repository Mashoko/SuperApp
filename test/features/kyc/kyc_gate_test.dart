import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/managers/call_activity.dart';
import 'package:mvvm_sip_demo/core/managers/emergency_call_failures.dart';
import 'package:mvvm_sip_demo/features/call/presentation/viewmodels/call_viewmodel.dart';
import 'package:mvvm_sip_demo/features/kyc/domain/emergency_numbers.dart';
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

/// Reports to [CallActivity] exactly like CallView: viewOpened in initState,
/// viewClosed in dispose.
class _FakeCallScreen extends StatefulWidget {
  const _FakeCallScreen({required this.activity});

  final CallActivity activity;

  @override
  State<_FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<_FakeCallScreen> {
  @override
  void initState() {
    super.initState();
    widget.activity.viewOpened();
  }

  @override
  void dispose() {
    widget.activity.viewClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Call screen'));
}

class _FakeCallViewModel implements CallViewModel {
  final calls = <(String, bool)>[];
  String? error;

  /// When set, makeCall waits for it before returning.
  Completer<void>? gate;

  @override
  Future<String?> makeCall(String destination,
      {required bool voiceOnly}) async {
    calls.add((destination, voiceOnly));
    if (gate != null) await gate!.future;
    return error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GlobalKey<NavigatorState> rootKey;
  late int signOuts;
  late ValueNotifier<bool> callActive;
  late KycGateNavigatorObserver observer;
  late List<Uri> launches;
  late Future<bool> Function(Uri) launchResult;
  late EmergencyCallFailures failures;

  setUp(() {
    rootKey = GlobalKey<NavigatorState>();
    signOuts = 0;
    callActive = ValueNotifier<bool>(false);
    observer = KycGateNavigatorObserver();
    launches = [];
    launchResult = (_) async => true;
    failures = EmergencyCallFailures();
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
        navigatorObservers: [observer],
        theme: ThemeData(
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light),
        home: const _AppHome(),
        builder: (context, child) => KycGate(
          navigatorKey: rootKey,
          callActive: callActive,
          emergencyCallFailures: failures,
          navigatorObserver: observer,
          launchDialer: (uri) {
            launches.add(uri);
            return launchResult(uri);
          },
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

    testWidgets(
        'the gate returns when a call screen closes (viewClosed in dispose)',
        (tester) async {
      final activity = CallActivity();
      callActive = activity;
      controller.status = _restricted();
      await pumpGate(tester, controller);
      expect(find.byType(MandatoryKycView), findsOneWidget);

      activity.callStarted('c1');
      unawaited(rootKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => _FakeCallScreen(activity: activity))));
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);
      expect(find.text('Call screen'), findsOneWidget);

      // The call ends; the end screen stays until the view closes.
      activity.callFinished('c1');
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);

      // Like CallView's auto-pop: dispose calls viewClosed mid-frame.
      rootKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(activity.value, isFalse);
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

    group('emergency call', () {
      late _FakeCallViewModel calls;

      setUp(() {
        calls = _FakeCallViewModel();
        getIt.registerFactory<CallViewModel>(() => calls);
      });

      tearDown(() => getIt.unregister<CallViewModel>());

      testWidgets('lists every emergency number and nothing else',
          (tester) async {
        controller.status = _restricted();
        await pumpGate(tester, controller);
        expect(find.byType(FilledButton), findsOneWidget,
            reason: 'Complete KYC now stays the only primary button');
        await tester.ensureVisible(find.text('Emergency call'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Emergency call'));
        await tester.pumpAndSettle();
        expect(find.text('Call emergency services'), findsOneWidget);
        for (final n in kEmergencyNumbers) {
          expect(find.text(n), findsOneWidget, reason: n);
        }
        expect(
            find.descendant(
                of: find.byType(BottomSheet), matching: find.byType(InkWell)),
            findsNWidgets(kEmergencyNumbers.length));
      });

      testWidgets('tapping a number places a voice call to it', (tester) async {
        controller.status = _restricted();
        await pumpGate(tester, controller);
        await tester.ensureVisible(find.text('Emergency call'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Emergency call'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('112'));
        await tester.pumpAndSettle();
        expect(calls.calls, [('112', true)]);
        expect(find.text('Call emergency services'), findsNothing);
      });

      Future<void> openSheet(WidgetTester tester) async {
        await tester.ensureVisible(find.text('Emergency call'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Emergency call'));
        await tester.pumpAndSettle();
      }

      const failBody = 'We could not start the call. '
          "Use your phone's dialer to call 999.";

      testWidgets('a failed call shows a dialog with the number',
          (tester) async {
        calls.error = 'Not connected.';
        controller.status = _restricted();
        await pumpGate(tester, controller);
        await openSheet(tester);
        await tester.tap(find.text('999'));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Call not started'), findsOneWidget);
        expect(find.text(failBody), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Open phone dialer'),
            findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);
        // Shown inside the gate, not on the app's navigator.
        final nav = Navigator.of(tester.element(find.text('Call not started')));
        expect(identical(nav, rootKey.currentState), isFalse);
        // Persistent: tapping outside does not close it.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Call not started'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(MandatoryKycView), findsOneWidget);
      });

      testWidgets('Open phone dialer launches tel: with the number',
          (tester) async {
        calls.error = 'Not connected.';
        controller.status = _restricted();
        await pumpGate(tester, controller);
        await openSheet(tester);
        await tester.tap(find.text('999'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open phone dialer'));
        await tester.pumpAndSettle();
        expect(launches, [Uri(scheme: 'tel', path: '999')]);
        expect(launches.single.toString(), 'tel:999');
        expect(find.byType(AlertDialog), findsNothing);
      });

      for (final throws in [false, true]) {
        testWidgets(
            'dialer ${throws ? 'throwing' : 'returning false'} keeps the '
            'dialog with the number to dial', (tester) async {
          launchResult = throws
              ? (_) async => throw StateError('no activity')
              : (_) async => false;
          calls.error = 'Not connected.';
          controller.status = _restricted();
          await pumpGate(tester, controller);
          await openSheet(tester);
          await tester.tap(find.text('999'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open phone dialer'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(launches, hasLength(1));
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text('Dial 999 on your phone.'), findsOneWidget);
          final selectable = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(SelectableText));
          expect(selectable, findsOneWidget);
          expect(tester.widget<SelectableText>(selectable).data, '999');
          // Readable, and still usable: the dialer can be tried again.
          final handle = tester.ensureSemantics();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
          expect(find.text('Open phone dialer'), findsOneWidget);
        });
      }

      testWidgets('double taps place one call', (tester) async {
        calls.gate = Completer<void>();
        calls.error = 'Not connected.';
        controller.status = _restricted();
        await pumpGate(tester, controller);
        await openSheet(tester);
        // Two quick taps on a row before the sheet has closed.
        await tester.tap(find.text('112'));
        await tester.tap(find.text('112'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(MandatoryKycView), findsOneWidget);
        expect(calls.calls, [('112', true)]);

        // While the call is being placed, Emergency call does nothing.
        await tester.ensureVisible(find.text('Emergency call'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Emergency call'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('Call emergency services'), findsNothing);
        expect(calls.calls, hasLength(1));

        calls.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Call not started'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        // Usable again once the attempt is over.
        await openSheet(tester);
        expect(find.text('Call emergency services'), findsOneWidget);
      });

      for (final size in const [
        Size(375, 667),
        Size(768, 1024),
        Size(1280, 800)
      ]) {
        testWidgets('sheet fits at ${size.width.toInt()} wide', (tester) async {
          final handle = tester.ensureSemantics();
          controller.status = _restricted();
          await pumpGate(tester, controller, size: size);
          await tester.ensureVisible(find.text('Emergency call'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Emergency call'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Rows are large targets. (The tap-target guideline is checked on
          // the page itself; here it would flag the page's buttons clipped
          // at the viewport edge behind the sheet.)
          for (final n in kEmergencyNumbers) {
            final row = tester.getSize(find.ancestor(
                of: find.text(n), matching: find.byType(InkWell)));
            expect(row.height, greaterThanOrEqualTo(48), reason: n);
            expect(row.width, greaterThanOrEqualTo(200), reason: n);
          }
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(find.bySemanticsLabel('Call 999'), findsOneWidget);
          handle.dispose();
        });
      }
    });

    group('an emergency call that started and then failed', () {
      const body999 = 'We could not start the call. '
          "Use your phone's dialer to call 999.";

      NavigatorState dialogNavigator(WidgetTester tester) =>
          Navigator.of(tester.element(find.text('Call not started')));

      testWidgets(
          'restricted: shown on the gate once the call screen has closed, '
          'and only once', (tester) async {
        final activity = CallActivity();
        callActive = activity;
        controller.status = _restricted();
        await pumpGate(tester, controller);

        activity.callStarted('c1');
        unawaited(rootKey.currentState!.push(MaterialPageRoute<void>(
            builder: (_) => _FakeCallScreen(activity: activity))));
        await tester.pumpAndSettle();

        // Like SipCallManager on FAILED: report, then the call finishes.
        failures.report('999');
        activity.callFinished('c1');
        await tester.pumpAndSettle();
        expect(find.text('Call not started'), findsNothing,
            reason: 'the call screen is still showing');
        expect(failures.value, '999');

        // Like CallView's auto-pop: dispose calls viewClosed mid-frame.
        rootKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(MandatoryKycView), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Call not started'), findsOneWidget);
        expect(find.text(body999), findsOneWidget);
        expect(identical(dialogNavigator(tester), rootKey.currentState),
            isFalse,
            reason: 'shown inside the gate, above the app');
        expect(failures.value, isNull);

        // Persistent: tapping outside does not close it.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Call not started'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        // Another call coming and going does not bring it back.
        activity.callStarted('c2');
        await tester.pumpAndSettle();
        activity.callFinished('c2');
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(MandatoryKycView), findsOneWidget);
      });

      testWidgets('not restricted: shown on the app navigator; dialer opens',
          (tester) async {
        controller.status = kycStatus(status: 'RESTRICTED', launched: false);
        await pumpGate(tester, controller);
        callActive.value = true;
        await tester.pumpAndSettle();

        failures.report('112');
        await tester.pumpAndSettle();
        expect(find.text('Call not started'), findsNothing);

        callActive.value = false;
        await tester.pumpAndSettle();
        expect(find.byType(MandatoryKycView), findsNothing);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
            find.text('We could not start the call. '
                "Use your phone's dialer to call 112."),
            findsOneWidget);
        expect(identical(dialogNavigator(tester), rootKey.currentState),
            isTrue);

        await tester.tap(find.text('Open phone dialer'));
        await tester.pumpAndSettle();
        expect(launches, [Uri(scheme: 'tel', path: '112')]);
        expect(find.byType(AlertDialog), findsNothing);

        callActive.value = true;
        await tester.pumpAndSettle();
        callActive.value = false;
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('reported with no call active: shown straight away',
          (tester) async {
        controller.status = _restricted();
        await pumpGate(tester, controller);
        failures.report('999');
        await tester.pumpAndSettle();
        expect(find.text(body999), findsOneWidget);
        expect(identical(dialogNavigator(tester), rootKey.currentState),
            isFalse);
      });
    });

    group('back stays blocked when the app changes its navigator', () {
      Future<void> expectBackBlocked(WidgetTester tester) async {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MandatoryKycView), findsOneWidget);
      }

      testWidgets('pushReplacement of the top route (login race)',
          (tester) async {
        controller.status = _restricted();
        await pumpGate(tester, controller);
        // Like LoginView: replaces whatever is on top with home.
        unawaited(rootKey.currentState!.pushReplacement(MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Home page')))));
        await tester.pumpAndSettle();
        await expectBackBlocked(tester);
        await expectBackBlocked(tester);
        controller.status = kycStatus(status: 'PENDING_REVIEW');
        controller.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.text('Home page'), findsOneWidget,
            reason: 'back did not pop the app page under the gate');
      });

      testWidgets('an app route pushed while gated', (tester) async {
        controller.status = _restricted();
        await pumpGate(tester, controller);
        unawaited(rootKey.currentState!.push(MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Late page')))));
        await tester.pumpAndSettle();
        await expectBackBlocked(tester);
        controller.status = kycStatus(status: 'PENDING_REVIEW');
        controller.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.text('Late page'), findsOneWidget);
      });

      testWidgets('a forced pop of the top route', (tester) async {
        controller.status = kycStatus(status: 'IN_PROGRESS');
        await pumpGate(tester, controller);
        unawaited(rootKey.currentState!.push(MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Detail page')))));
        await tester.pumpAndSettle();
        controller.status = _restricted();
        controller.notifyListeners();
        await tester.pumpAndSettle();
        // Something in the app calls pop() directly (not maybePop).
        rootKey.currentState!.pop();
        await tester.pumpAndSettle();
        await expectBackBlocked(tester);
        controller.status = kycStatus(status: 'PENDING_REVIEW');
        controller.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.text('Detail page'), findsOneWidget,
            reason: 'only the blocker was popped, then restored');
      });
    });

    testWidgets('tearing down the app while gated does not throw',
        (tester) async {
      controller.status = _restricted();
      await pumpGate(tester, controller);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('removing the gate while the app navigator lives on',
        (tester) async {
      controller.status = _restricted();
      await pumpGate(tester, controller);
      await tester.pumpWidget(ChangeNotifierProvider<KycStatusController>.value(
        value: controller,
        child: MaterialApp(
          navigatorKey: rootKey,
          home: const _AppHome(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(rootKey.currentState!.canPop(), isFalse,
          reason: 'the back blocker was removed with the gate');
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
      await tester.ensureVisible(find.text('Sign out'));
      await tester.pumpAndSettle();
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

    testWidgets(
        'loading and error states keep Emergency call, Contact support and '
        'Sign out', (tester) async {
      controller.status = null;
      await tester.pumpWidget(ChangeNotifierProvider<KycStatusController>.value(
        value: controller,
        child: MaterialApp(
          home: MandatoryKycView(
              onCompleteNow: () {}, onContactSupport: () {}, onSignOut: () {}),
        ),
      ));
      // Loading: no status, no error yet.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      for (final label in ['Emergency call', 'Contact support', 'Sign out']) {
        expect(find.text(label), findsOneWidget, reason: 'loading: $label');
      }
      expect(find.text('Complete KYC now'), findsNothing);

      // Error with no status.
      controller.error = 'You are offline.';
      controller.notifyListeners();
      await tester.pump();
      expect(find.text('You are offline.'), findsOneWidget);
      for (final label in ['Emergency call', 'Contact support', 'Sign out']) {
        expect(find.text(label), findsOneWidget, reason: 'error: $label');
      }
      expect(find.text('Complete KYC now'), findsNothing);
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
          await tester.ensureVisible(find.text('Sign out'));
          await tester.pumpAndSettle();
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

    const thanks = 'Thanks. We are reviewing your details. '
        'You can keep using the app while we check.';

    /// Restricts via markRestricted, opens the real form and walks to the
    /// review step.
    Future<void> restrictAndOpenForm(WidgetTester tester) async {
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
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Submit for review'));
      await tester.pumpAndSettle();
    }

    Future<void> finish(WidgetTester tester) async {
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
        'markRestricted, gate shows, back does nothing, submit shows thanks, '
        'Done lifts the gate', (tester) async {
      await restrictAndOpenForm(tester);
      service.statusResult = kycStatus(status: 'PENDING_REVIEW');
      await submit(tester);
      expect(service.submits, 1);
      expect(controller.status!.isPendingReview, isTrue);
      // The gate stays up on the thanks state until Done.
      expect(find.text(thanks), findsOneWidget);
      expect(find.byType(KycFormView), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);
      expect(find.byType(KycFormView), findsNothing);
      expect(find.text('App button 0'), findsOneWidget);
      await tester.tap(find.text('App button 0'));
      await tester.pump();
      expect(find.text('App button 1'), findsOneWidget);
      await finish(tester);
    });

    testWidgets(
        'submit succeeds but the refresh fails: PENDING_REVIEW, Done lifts '
        'the gate', (tester) async {
      await restrictAndOpenForm(tester);
      service.statusResult = null; // getStatus now fails (offline).
      await submit(tester);
      expect(service.submits, 1);
      expect(controller.error, isNotNull, reason: 'the refresh did fail');
      expect(controller.status!.status, 'PENDING_REVIEW');
      expect(controller.isRestricted, isFalse);
      expect(find.text(thanks), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);
      expect(find.byType(KycFormView), findsNothing);
      expect(find.text('App button 0'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('back on the thanks state also lifts the gate', (tester) async {
      await restrictAndOpenForm(tester);
      service.statusResult = kycStatus(status: 'PENDING_REVIEW');
      await submit(tester);
      expect(find.text(thanks), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MandatoryKycView), findsNothing);
      expect(find.byType(KycFormView), findsNothing);
      expect(find.text('App button 0'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a failed submit releases the hold; the gate stays',
        (tester) async {
      await restrictAndOpenForm(tester);
      service.submitError = KycApiException(500, 'Could not send.');
      await submit(tester);
      expect(find.text('Could not send.'), findsOneWidget);
      // Still restricted: back closes the form, the mandatory screen stays.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(KycFormView), findsNothing);
      expect(find.byType(MandatoryKycView), findsOneWidget);
      await finish(tester);
    });
  });
}
