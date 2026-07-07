import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/glass_bottom_nav.dart';

const _tabs = [
  GlassNavTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
  GlassNavTab(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'Explore'),
  GlassNavTab(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Shop'),
  GlassNavTab(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
];

Widget _harness({
  required int activeIndex,
  required ValueChanged<int> onTabSelected,
  bool visible = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        child: GlassBottomNav(
          tabs: _tabs,
          activeIndex: activeIndex,
          onTabSelected: onTabSelected,
          onDialerTap: () {},
          quickActions: const [],
          visible: visible,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping a tab label invokes onTabSelected with its index',
      (tester) async {
    int? selected;
    await tester.pumpWidget(
        _harness(activeIndex: 0, onTabSelected: (i) => selected = i));

    await tester.tap(find.text('Explore'));
    await tester.pump();

    expect(selected, 1);
  });

  testWidgets('sliding indicator moves to the active tab slot', (tester) async {
    await tester.pumpWidget(_harness(activeIndex: 0, onTabSelected: (_) {}));
    final atIndex0 = tester
        .widget<AnimatedPositioned>(find.byKey(const Key('glass-nav-indicator')))
        .left;

    await tester.pumpWidget(_harness(activeIndex: 2, onTabSelected: (_) {}));
    await tester.pumpAndSettle();
    final atIndex2 = tester
        .widget<AnimatedPositioned>(find.byKey(const Key('glass-nav-indicator')))
        .left;

    // 400px wide, 4 tabs => 100px slots. Index 0 center=50, index 2 center=250.
    expect(atIndex0, 36.0); // 50 - indicatorWidth(28)/2
    expect(atIndex2, 236.0); // 250 - 14
  });

  testWidgets('visible=false slides the nav down and out', (tester) async {
    await tester.pumpWidget(
        _harness(activeIndex: 0, onTabSelected: (_) {}, visible: false));
    await tester.pump(const Duration(milliseconds: 400));

    final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
    expect(slide.offset, const Offset(0, 1.6));
  });
}
