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

  testWidgets('short tap on the PAD calls onDialerTap and does not open the fan',
      (tester) async {
    var dialerTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: GlassBottomNav(
            tabs: _tabs,
            activeIndex: 0,
            onTabSelected: (_) {},
            onDialerTap: () => dialerTaps++,
            quickActions: [
              GlassNavQuickAction(
                  icon: Icons.send_outlined, label: 'Send', onTap: () {}),
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('glass-nav-pad')));
    await tester.pump();

    expect(dialerTaps, 1);
    expect(find.byIcon(Icons.send_outlined), findsNothing);
  });

  testWidgets('long-press on the PAD opens the fan with all quick actions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: GlassBottomNav(
            tabs: _tabs,
            activeIndex: 0,
            onTabSelected: (_) {},
            onDialerTap: () {},
            quickActions: [
              GlassNavQuickAction(
                  icon: Icons.send_outlined, label: 'Send', onTap: () {}),
              GlassNavQuickAction(
                  icon: Icons.qr_code_scanner_outlined,
                  label: 'Scan',
                  onTap: () {}),
              GlassNavQuickAction(
                  icon: Icons.payments_outlined, label: 'Pay', onTap: () {}),
            ],
          ),
        ),
      ),
    ));

    await tester.longPress(find.byKey(const Key('glass-nav-pad')));
    await tester.pump();
    // Fan entries stagger in (0ms, 45ms, 90ms) — advance past the last one.
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_outlined), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
  });

  testWidgets('tapping the scrim closes the fan', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: GlassBottomNav(
            tabs: _tabs,
            activeIndex: 0,
            onTabSelected: (_) {},
            onDialerTap: () {},
            quickActions: [
              GlassNavQuickAction(
                  icon: Icons.send_outlined, label: 'Send', onTap: () {}),
            ],
          ),
        ),
      ),
    ));

    await tester.longPress(find.byKey(const Key('glass-nav-pad')));
    await tester.pump();
    expect(find.byIcon(Icons.send_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('glass-nav-scrim')));
    await tester.pump();
    expect(find.byIcon(Icons.send_outlined), findsNothing);
  });

  testWidgets('tapping a quick action closes the fan and fires its onTap',
      (tester) async {
    var sendTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: GlassBottomNav(
            tabs: _tabs,
            activeIndex: 0,
            onTabSelected: (_) {},
            onDialerTap: () {},
            quickActions: [
              GlassNavQuickAction(
                  icon: Icons.send_outlined,
                  label: 'Send',
                  onTap: () => sendTaps++),
            ],
          ),
        ),
      ),
    ));

    await tester.longPress(find.byKey(const Key('glass-nav-pad')));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();

    expect(sendTaps, 1);
    expect(find.byIcon(Icons.send_outlined), findsNothing);
  });
}
