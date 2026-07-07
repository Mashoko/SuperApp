import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/services_grid_section.dart';

void main() {
  testWidgets(
      'renders inside a scrolling parent without its own Scaffold/scroll view',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              ServicesGridSection(),
            ],
          ),
        ),
      ),
    ));

    expect(find.text('Calling'), findsOneWidget);
    expect(find.text('Utility Bills'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Call History'), findsOneWidget);
    expect(find.text('Order History'), findsOneWidget);
  });
}
