import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/widgets/dialer_glass_nav.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('highlights Recents when activeIndex is 0', (tester) async {
    await tester.pumpWidget(wrap(DialerGlassNav(
      activeIndex: 0,
      onTabSelected: (_) {},
      onMarketPlaceTap: () {},
    )));

    final recentsIcon =
        tester.widget<Icon>(find.byIcon(Icons.access_time_filled));
    final contactsIcon =
        tester.widget<Icon>(find.byIcon(Icons.contacts_outlined));
    expect(recentsIcon.color, WunzaColors.dialerNavActive);
    expect(contactsIcon.color, Colors.white54);
  });

  testWidgets('highlights Contacts when activeIndex is 1', (tester) async {
    await tester.pumpWidget(wrap(DialerGlassNav(
      activeIndex: 1,
      onTabSelected: (_) {},
      onMarketPlaceTap: () {},
    )));

    final contactsIcon = tester.widget<Icon>(find.byIcon(Icons.contacts));
    expect(contactsIcon.color, WunzaColors.dialerNavActive);
  });

  testWidgets('tapping Contacts calls onTabSelected(1)', (tester) async {
    int? selected;
    await tester.pumpWidget(wrap(DialerGlassNav(
      activeIndex: 0,
      onTabSelected: (i) => selected = i,
      onMarketPlaceTap: () {},
    )));

    await tester.tap(find.text('Contacts'));
    expect(selected, 1);
  });

  testWidgets('tapping Market Place calls onMarketPlaceTap, not onTabSelected',
      (tester) async {
    int? selected;
    var marketPlaceTapped = false;
    await tester.pumpWidget(wrap(DialerGlassNav(
      activeIndex: 0,
      onTabSelected: (i) => selected = i,
      onMarketPlaceTap: () => marketPlaceTapped = true,
    )));

    await tester.tap(find.text('Market Place'));
    expect(marketPlaceTapped, true);
    expect(selected, null);
  });
}
