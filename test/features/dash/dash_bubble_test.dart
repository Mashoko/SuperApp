import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/viewmodels/dash_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/widgets/dash_bubble.dart';
import 'package:mvvm_sip_demo/features/faq/data/faq_service.dart';
import 'package:mvvm_sip_demo/features/faq/presentation/viewmodels/faq_viewmodel.dart';

Widget _harness(DashViewModel vm) {
  return ChangeNotifierProvider<DashViewModel>.value(
    value: vm,
    child: const MaterialApp(home: Scaffold(body: DashBubble())),
  );
}

void main() {
  testWidgets('shows the nudge dot when the nudge has not been dismissed',
      (tester) async {
    final vm = DashViewModel(FaqViewModel(FaqService()));
    await tester.pumpWidget(_harness(vm));
    expect(find.byKey(const Key('dash_nudge_dot')), findsOneWidget);
  });

  testWidgets('hides the nudge dot once dismissed', (tester) async {
    final vm = DashViewModel(FaqViewModel(FaqService()))..dismissNudge();
    await tester.pumpWidget(_harness(vm));
    expect(find.byKey(const Key('dash_nudge_dot')), findsNothing);
  });
}
