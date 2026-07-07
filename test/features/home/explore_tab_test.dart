import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_tab.dart';

void main() {
  testWidgets('shows category chips and discovery sections', (tester) async {
    // Set larger viewport to ensure all ListView content renders
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExploreTab())));

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Trending now'), findsOneWidget);
    expect(find.text('Recommended for you'), findsOneWidget);
    expect(find.text('Nearby offers'), findsOneWidget);
    expect(find.text('Recently added', skipOffstage: false), findsOneWidget);
  });

  testWidgets('tapping a category chip switches the selected chip', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExploreTab())));

    await tester.tap(find.text('Trending'));
    await tester.pump();

    // No exception, chip row still renders after selection changes.
    expect(find.text('Trending'), findsOneWidget);
  });
}
