import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_tab.dart';

void main() {
  testWidgets(
      'renders search bar, categories, banner, and all flagship sections',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExploreTab())));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
        find.text('Search products, businesses, events, services, people...'),
        findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.text('Recommended Products'), findsOneWidget);
    expect(find.text('Popular Businesses'), findsOneWidget);
    expect(find.text('Deals & Promotions'), findsOneWidget);
  });

  testWidgets('tapping a category chip selects it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExploreTab())));

    await tester.tap(find.text('Services'));
    await tester.pump();

    final chip = tester.widget<ChoiceChip>(
      find.ancestor(of: find.text('Services'), matching: find.byType(ChoiceChip)),
    );
    expect(chip.selected, true);
  });

  testWidgets('tapping the search bar opens the search sheet', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExploreTab())));

    await tester.tap(find
        .text('Search products, businesses, events, services, people...'));
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsOneWidget);
  });

  testWidgets('swiping the banner carousel updates the active dot',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExploreTab())));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    final dot0 = tester
        .widget<AnimatedContainer>(find.byKey(const Key('banner-dot-0')))
        .decoration as BoxDecoration;
    final dot1 = tester
        .widget<AnimatedContainer>(find.byKey(const Key('banner-dot-1')))
        .decoration as BoxDecoration;

    expect(dot1.color, WunzaColors.navIndicator);
    expect(dot0.color, WunzaColors.navIndicator.withValues(alpha: 0.25));
  });
}
