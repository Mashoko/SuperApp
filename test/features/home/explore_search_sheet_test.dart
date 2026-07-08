import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_search_sheet.dart';

void main() {
  testWidgets('shows recent searches, trending searches, and categories by default',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreSearchSheet()));
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Wireless earbuds'), findsOneWidget);
    expect(find.text('Trending searches'), findsOneWidget);
    expect(find.text('Browse by category'), findsOneWidget);
  });

  testWidgets('typing filters suggestions by substring match', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreSearchSheet()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'earbuds');
    await tester.pump();

    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.textContaining('Wireless earbuds'), findsOneWidget);
    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('removing a recent search removes it from the list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreSearchSheet()));
    await tester.pumpAndSettle();

    expect(find.text('Wireless earbuds'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, 'Wireless earbuds'),
      matching: find.byIcon(Icons.close),
    ));
    await tester.pump();

    expect(find.text('Wireless earbuds'), findsNothing);
  });

  testWidgets('a whitespace-only query does not show spurious suggestions',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreSearchSheet()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Suggestions'), findsNothing);
  });
}
