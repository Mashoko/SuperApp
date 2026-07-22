import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:mvvm_sip_demo/core/di/inject.dart' show getIt;
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/viewmodels/dash_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/widgets/dash_sheet.dart';
import 'package:mvvm_sip_demo/payments_client.dart';
import 'package:mvvm_sip_demo/users_client.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

Widget _harness(DashViewModel dashVm) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DashViewModel>.value(value: dashVm),
      ChangeNotifierProvider<AccountSummaryViewModel>(
        create: (_) => AccountSummaryViewModel(
          OtpAuthService(UsersClient(packageId: 'test')),
          PaymentsClient(packageId: 'test'),
        ),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SizedBox.shrink()),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester, DashViewModel dashVm) async {
  await tester.pumpWidget(_harness(dashVm));
  final context = tester.element(find.byType(Scaffold));
  unawaited(showDashSheet(context));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeUrlLauncher fakeLauncher;

  setUp(() {
    fakeLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
    // `openWhatsAppSupport` reads stored credentials via SharedPreferences;
    // without a mock store, `SharedPreferences.getInstance()` never resolves
    // in a widget test (no platform channel handler is registered), which
    // would hang `_submit` forever.
    SharedPreferences.setMockInitialValues({});
    // `openWhatsAppSupport` (used by DashSheet's "Talk to a human" escalation)
    // reads `getIt<OtpAuthService>()` directly from the global service
    // locator rather than via provider, so it must be registered here even
    // though this test never triggers real network I/O.
    if (!getIt.isRegistered<OtpAuthService>()) {
      getIt.registerSingleton<OtpAuthService>(
        OtpAuthService(UsersClient(packageId: 'test')),
      );
    }
  });

  tearDown(() {
    if (getIt.isRegistered<OtpAuthService>()) {
      getIt.unregister<OtpAuthService>();
    }
  });

  testWidgets('shows the empty-state greeting when there are no messages',
      (tester) async {
    await _openSheet(tester, DashViewModel());
    expect(find.textContaining("Hi! I'm Dash"), findsOneWidget);
  });

  testWidgets('shows the disclaimer under the input', (tester) async {
    await _openSheet(tester, DashViewModel());
    expect(
      find.text('Dash is an AI assistant and can make mistakes.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping the "Check data balance" chip adds a user message and a reply',
      (tester) async {
    await _openSheet(tester, DashViewModel());
    await tester.tap(find.text('Check data balance'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Check data balance'), findsWidgets);
    expect(find.textContaining('Data'), findsWidgets);
  });

  testWidgets('tapping "Talk to a human" launches WhatsApp support',
      (tester) async {
    await _openSheet(tester, DashViewModel());
    await tester.tap(find.text('Talk to a human'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(fakeLauncher.launchedUrls, isNotEmpty);
    expect(fakeLauncher.launchedUrls.single, contains('wa.me'));
  });
}
