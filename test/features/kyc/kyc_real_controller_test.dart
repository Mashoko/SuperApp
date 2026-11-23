import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_form_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_form_viewmodel.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_controller.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/widgets/kyc_banner.dart';
import 'package:provider/provider.dart';

import 'kyc_test_fakes.dart';

/// Regression: the REAL controller notifies synchronously when a refresh
/// starts with no status. Screens that refresh on open must not do it during
/// build, or every Provider listener throws "markNeedsBuild during build".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeKycService service;
  late KycStatusController controller;

  setUp(() {
    // The controller is built outside fake-async so its poll timer is not
    // reported as pending.
    service = FakeKycService();
    controller = KycStatusController(service);
  });

  tearDown(() => controller.dispose());

  Future<void> pumpWith(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Created inside the test zone so completing it runs under fake-async.
    service.statusGate = Completer<void>();
    await tester.pumpWidget(ChangeNotifierProvider<KycStatusController>.value(
      value: controller,
      child: MaterialApp(
        home: Scaffold(
          body: Column(children: [
            // A Provider listener above the screen, like the home banner.
            const KycBanner(),
            Expanded(child: screen),
          ]),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.loading, isTrue, reason: 'refresh started');
    service.statusResult = kycStatus(status: 'IN_PROGRESS', draft: completeDraft);
    service.statusGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(service.statusCalls, 1);
  }

  testWidgets('KycFormView opens with no status and a listener present',
      (tester) async {
    final vm = KycFormViewModel(service, controller);
    addTearDown(vm.dispose);
    await pumpWith(tester, KycFormView(viewModel: vm));
    expect(find.text('Verify your number'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('KycStatusView opens with no status and a listener present',
      (tester) async {
    await pumpWith(tester, const KycStatusView());
    expect(find.text('In progress'), findsOneWidget);
  });
}
