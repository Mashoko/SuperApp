import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/call/domain/entities/phone_call_state.dart';
import 'package:mvvm_sip_demo/features/call/presentation/views/call_view.dart';

void main() {
  late GlobalKey<NavigatorState> rootKey;

  setUp(() => rootKey = GlobalKey<NavigatorState>());

  Future<void> pumpCall(WidgetTester tester, PhoneCallState state) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: rootKey,
      home: const Scaffold(body: Text('Home')),
    ));
    rootKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => CallPopGuard(
        state: state,
        child: const Scaffold(body: Text('Call screen')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Call screen'), findsOneWidget);
  }

  for (final state in [
    PhoneCallState.calling,
    PhoneCallState.ringing,
    PhoneCallState.incoming,
    PhoneCallState.connected,
  ]) {
    testWidgets('system back does nothing while ${state.name}', (tester) async {
      await pumpCall(tester, state);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Call screen'), findsOneWidget);
    });
  }

  for (final state in [PhoneCallState.ended, PhoneCallState.failed]) {
    testWidgets('system back closes the screen once ${state.name}',
        (tester) async {
      await pumpCall(tester, state);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Call screen'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  }

  testWidgets('the end-of-call auto-pop (Navigator.pop) still works',
      (tester) async {
    await pumpCall(tester, PhoneCallState.ended);
    rootKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Call screen'), findsNothing);
  });
}
