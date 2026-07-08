import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/discovery_section.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart';

const _items = [
  DiscoveryItem(
    id: '1',
    title: 'Item One',
    subtitle: 'Sub one',
    tintColor: Colors.blue,
  ),
  DiscoveryItem(
    id: '2',
    title: 'Item Two',
    subtitle: 'Sub two',
    tintColor: Colors.red,
    badge: 'New',
  ),
];

void main() {
  testWidgets('renders title, subtitle, and item cards', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DiscoverySection(
          title: 'Test Section',
          subtitle: 'Test subtitle',
          items: _items,
          onSeeAll: () {},
        ),
      ),
    ));

    expect(find.text('Test Section'), findsOneWidget);
    expect(find.text('Test subtitle'), findsOneWidget);
    expect(find.text('Item One'), findsOneWidget);
    expect(find.text('Sub one'), findsOneWidget);
    expect(find.text('Item Two'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('tapping See all invokes onSeeAll', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DiscoverySection(
          title: 'Test Section',
          subtitle: 'Test subtitle',
          items: _items,
          onSeeAll: () => taps++,
        ),
      ),
    ));

    await tester.tap(find.text('See all'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('each card exposes a semantics label with title and subtitle',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DiscoverySection(
          title: 'Test Section',
          subtitle: 'Test subtitle',
          items: _items,
          onSeeAll: () {},
        ),
      ),
    ));

    expect(find.bySemanticsLabel('Item One, Sub one'), findsOneWidget);
    expect(find.bySemanticsLabel('Item Two, Sub two'), findsOneWidget);
  });
}
