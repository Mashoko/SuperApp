# Glass Bottom Nav Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SuperApp's flat `BottomAppBar` + docked FAB with a floating glassmorphic pill nav (`GlassBottomNav`) that has an embedded gradient PAD button (tap = dialer, long-press = Send/Scan/Pay fan-out), a sliding violet active-tab indicator, and scroll-aware show/hide — matching the approved `GlassNav.jsx` mockup, ported to Flutter.

**Architecture:** A new self-contained `GlassBottomNav` widget (tabs row + sliding indicator + embedded PAD + its own Overlay-based fan-out popup) replaces `HomeView`'s `_buildBottomNav`/`HangingDialerButton`. `HomeView` positions it as a floating `Positioned` widget inside its body `Stack` (not `Scaffold.bottomNavigationBar`, since that can't slide fully off-screen). The old `Services` tab is retired: its grid becomes an embedded section in the `Home` tab, and a new placeholder `ExploreTab` takes its slot in the bar.

**Tech Stack:** Flutter (Material 3), no new packages — `dart:ui` (`ImageFilter` for glass blur), `dart:math` (fan-angle trig), `flutter_test` for widget tests.

## Global Constraints

- No new pub packages. Everything uses Flutter SDK APIs already available (`BackdropFilter`, `Overlay`, `AnimatedPositioned`, etc.).
- Only additive color tokens in `WunzaColors` this phase — do not modify or remove `glidePrimary`/`glideAccent`/etc. (phase 2 concern, out of scope here).
- `Send`/`Scan`/`Pay` quick actions open the existing `MaintenanceScreen` ("Coming soon") — no new routes, no backend wiring.
- Every existing destination reachable from the old `Services` tab (`Calling`, `Utility Bills`, `Payments`, `Providers`, `Call History`, `Order History`) must remain reachable after this change — none may regress.
- Follow existing repo conventions: `WunzaColors` for palette constants, `Theme.of(context)` for brightness-aware values, `package:mvvm_sip_demo/...` import style.

---

### Task 1: Nav color tokens

**Files:**
- Modify: `lib/core/theme.dart` (append to `WunzaColors`, after the existing `primaryGradient` field, before the closing `}` of the class — do not touch any other existing field)
- Test: `test/core/theme_nav_tokens_test.dart`

**Interfaces:**
- Produces: `WunzaColors.navBgDark`, `WunzaColors.navBgLight`, `WunzaColors.navGlassDark`, `WunzaColors.navGlassLight`, `WunzaColors.navIndicator`, `WunzaColors.padGradientStart`, `WunzaColors.padGradientEnd` — all `Color`, consumed by Task 2 and Task 3.

- [ ] **Step 1: Write the failing test**

Create `test/core/theme_nav_tokens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

void main() {
  test('nav token colors match the glass-bottom-nav design spec', () {
    expect(WunzaColors.navBgDark, const Color(0xFF0B0B0E));
    expect(WunzaColors.navBgLight, const Color(0xFFF2F1EE));
    expect(WunzaColors.navGlassDark, const Color(0x801E1E24));
    expect(WunzaColors.navGlassLight, const Color(0x8CFFFFFF));
    expect(WunzaColors.navIndicator, const Color(0xFF9B8CFF));
    expect(WunzaColors.padGradientStart, const Color(0xFFFF7A45));
    expect(WunzaColors.padGradientEnd, const Color(0xFFFF4D6D));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme_nav_tokens_test.dart`
Expected: FAIL — compile error, `navBgDark` (and the other fields) undefined on `WunzaColors`.

- [ ] **Step 3: Add the tokens**

In `lib/core/theme.dart`, inside `class WunzaColors`, immediately after the `primaryGradient` field (before the class's closing `}`), add:

```dart

  // --- Glass bottom nav tokens (nav-scoped only; phase 2 folds these
  // into the app-wide ColorScheme) ---
  static const Color navBgDark = Color(0xFF0B0B0E);
  static const Color navBgLight = Color(0xFFF2F1EE);
  static const Color navGlassDark = Color(0x801E1E24); // rgba(30,30,36,0.5)
  static const Color navGlassLight = Color(0x8CFFFFFF); // rgba(255,255,255,0.55)
  static const Color navIndicator = Color(0xFF9B8CFF); // violet, active-tab glow only
  static const Color padGradientStart = Color(0xFFFF7A45); // coral
  static const Color padGradientEnd = Color(0xFFFF4D6D); // pink
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme_nav_tokens_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme.dart test/core/theme_nav_tokens_test.dart
git commit -m "feat(theme): add glass bottom nav color tokens"
```

---

### Task 2: `GlassBottomNav` shell — tabs, sliding indicator, visibility

**Files:**
- Create: `lib/features/home/presentation/widgets/glass_bottom_nav.dart`
- Test: `test/features/home/glass_bottom_nav_test.dart`

**Interfaces:**
- Consumes: `WunzaColors.navGlassDark/navGlassLight/navIndicator` (Task 1).
- Produces:
  - `class GlassNavTab { const GlassNavTab({required IconData icon, required IconData activeIcon, required String label}); }`
  - `class GlassNavQuickAction { const GlassNavQuickAction({required IconData icon, required String label, required VoidCallback onTap}); }`
  - `class GlassBottomNav extends StatefulWidget` with constructor `GlassBottomNav({Key? key, required List<GlassNavTab> tabs, required int activeIndex, required ValueChanged<int> onTabSelected, required VoidCallback onDialerTap, required List<GlassNavQuickAction> quickActions, bool visible = true})`.
  - These four names/signatures are relied on by Task 3 (extends this file) and Task 6 (`HomeView` wiring).

- [ ] **Step 1: Write the failing test**

Create `test/features/home/glass_bottom_nav_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/glass_bottom_nav_test.dart`
Expected: FAIL — `package:mvvm_sip_demo/features/home/presentation/widgets/glass_bottom_nav.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/features/home/presentation/widgets/glass_bottom_nav.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

/// Respects reduced-motion: collapses to instant when the platform/user has
/// disabled animations (Flutter's equivalent of `prefers-reduced-motion`).
Duration _motionDuration(BuildContext context, Duration normal) {
  return MediaQuery.of(context).disableAnimations ? Duration.zero : normal;
}

/// One tab in [GlassBottomNav]. Exactly 4 tabs are supported — the PAD is
/// visually centered at the 50% mark, which only lines up between tabs 1
/// and 2 when there are 4 of them (matches the approved design).
class GlassNavTab {
  const GlassNavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// One quick action shown when the PAD is long-pressed.
class GlassNavQuickAction {
  const GlassNavQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class GlassBottomNav extends StatefulWidget {
  const GlassBottomNav({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onDialerTap,
    required this.quickActions,
    this.visible = true,
  });

  final List<GlassNavTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onDialerTap;
  final List<GlassNavQuickAction> quickActions;
  final bool visible;

  @override
  State<GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends State<GlassBottomNav> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor =
        isDark ? WunzaColors.navGlassDark : WunzaColors.navGlassLight;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.65);

    return AnimatedSlide(
      duration: _motionDuration(context, const Duration(milliseconds: 320)),
      curve: Curves.easeOutCubic,
      offset: widget.visible ? Offset.zero : const Offset(0, 1.6),
      child: SizedBox(
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      _SlidingIndicator(
                        activeIndex: widget.activeIndex,
                        tabCount: widget.tabs.length,
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < widget.tabs.length; i++)
                            Expanded(
                              child: _GlassTabButton(
                                tab: widget.tabs[i],
                                isActive: i == widget.activeIndex,
                                onTap: () => widget.onTabSelected(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        WunzaColors.padGradientStart,
                        WunzaColors.padGradientEnd,
                      ],
                    ),
                  ),
                  child: const Icon(Icons.dialpad,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidingIndicator extends StatelessWidget {
  const _SlidingIndicator({required this.activeIndex, required this.tabCount});

  final int activeIndex;
  final int tabCount;

  static const double _width = 28;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / tabCount;
        final left = slotWidth * activeIndex + slotWidth / 2 - _width / 2;
        return AnimatedPositioned(
          key: const Key('glass-nav-indicator'),
          duration: _motionDuration(context, const Duration(milliseconds: 320)),
          curve: Curves.easeOutCubic,
          bottom: 8,
          left: left,
          child: Container(
            width: _width,
            height: 3,
            decoration: BoxDecoration(
              color: WunzaColors.navIndicator,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: WunzaColors.navIndicator.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GlassTabButton extends StatelessWidget {
  const _GlassTabButton({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final GlassNavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final color = isActive ? onSurface : onSurface.withValues(alpha: 0.56);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: tab.label,
          selected: isActive,
          button: true,
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isActive ? 1.14 : 1.0,
                  duration: _motionDuration(context, const Duration(milliseconds: 300)),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isActive ? tab.activeIcon : tab.icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedOpacity(
                  opacity: isActive ? 1 : 0,
                  duration: _motionDuration(context, const Duration(milliseconds: 220)),
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/glass_bottom_nav_test.dart`
Expected: PASS (3 tests). Note the PAD in this step has no `onTap`/`onLongPress` wired yet — that's Task 3 — so this step only exercises tabs/indicator/visibility.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/glass_bottom_nav.dart test/features/home/glass_bottom_nav_test.dart
git commit -m "feat(home): add GlassBottomNav shell with sliding indicator"
```

---

### Task 3: PAD tap + long-press fan-out

**Files:**
- Modify: `lib/features/home/presentation/widgets/glass_bottom_nav.dart`
- Test: `test/features/home/glass_bottom_nav_test.dart` (append tests)

**Interfaces:**
- Consumes: `GlassBottomNav`, `GlassNavQuickAction` (Task 2).
- Produces: no new public names — `onDialerTap`/`quickActions` (already part of the Task 2 constructor) become functional.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/home/glass_bottom_nav_test.dart` (inside `void main() { ... }`, after the existing tests, before the closing `}`):

```dart

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
    expect(find.text('Send'), findsNothing);
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

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Pay'), findsOneWidget);
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
    expect(find.text('Send'), findsOneWidget);

    await tester.tap(find.byKey(const Key('glass-nav-scrim')));
    await tester.pump();
    expect(find.text('Send'), findsNothing);
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

    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(sendTaps, 1);
    expect(find.text('Send'), findsNothing);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/home/glass_bottom_nav_test.dart`
Expected: FAIL — `Key('glass-nav-pad')` and `Key('glass-nav-scrim')` not found (PAD currently has no `key`, no gesture handling, no fan-out).

- [ ] **Step 3: Implement PAD gestures and the fan-out overlay**

In `lib/features/home/presentation/widgets/glass_bottom_nav.dart`, add `import 'dart:math' as math;` at the top (alongside the existing `dart:ui` import).

Replace the `_GlassBottomNavState` class entirely with:

```dart
class _GlassBottomNavState extends State<GlassBottomNav> {
  OverlayEntry? _fanEntry;

  void _openFan() {
    if (_fanEntry != null || widget.quickActions.isEmpty) return;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: _QuickActionFan(
          actions: widget.quickActions,
          onDismiss: _closeFan,
        ),
      ),
    );
    overlay.insert(entry);
    _fanEntry = entry;
  }

  void _closeFan() {
    _fanEntry?.remove();
    _fanEntry = null;
  }

  void _onPadTap() {
    _closeFan();
    widget.onDialerTap();
  }

  @override
  void dispose() {
    _fanEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor =
        isDark ? WunzaColors.navGlassDark : WunzaColors.navGlassLight;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.65);

    return AnimatedSlide(
      duration: _motionDuration(context, const Duration(milliseconds: 320)),
      curve: Curves.easeOutCubic,
      offset: widget.visible ? Offset.zero : const Offset(0, 1.6),
      child: SizedBox(
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      _SlidingIndicator(
                        activeIndex: widget.activeIndex,
                        tabCount: widget.tabs.length,
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < widget.tabs.length; i++)
                            Expanded(
                              child: _GlassTabButton(
                                tab: widget.tabs[i],
                                isActive: i == widget.activeIndex,
                                onTap: () => widget.onTabSelected(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  key: const Key('glass-nav-pad'),
                  onTap: _onPadTap,
                  onLongPress: widget.quickActions.isEmpty ? null : _openFan,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          WunzaColors.padGradientStart,
                          WunzaColors.padGradientEnd,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              WunzaColors.padGradientEnd.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.dialpad,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen scrim + radially-arranged quick actions, shown via [Overlay]
/// so it can dim/dismiss over the whole screen regardless of where
/// [GlassBottomNav] itself is positioned.
class _QuickActionFan extends StatelessWidget {
  const _QuickActionFan({required this.actions, required this.onDismiss});

  final List<GlassNavQuickAction> actions;
  final VoidCallback onDismiss;

  static List<double> _anglesFor(int count) {
    if (count == 1) return const [-90];
    if (count == 2) return const [-130, -50];
    if (count == 3) return const [-150, -90, -30];
    return List.generate(
        count, (i) => -180 + (180 / (count + 1)) * (i + 1));
  }

  @override
  Widget build(BuildContext context) {
    final angles = _anglesFor(actions.length);
    const dist = 78.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('glass-nav-scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withValues(alpha: 0.28)),
            ),
          ),
        ),
        for (var i = 0; i < actions.length; i++)
          Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(
                math.cos(angles[i] * math.pi / 180) * dist,
                math.sin(angles[i] * math.pi / 180) * dist - 110,
              ),
              child: _FanActionButton(
                action: actions[i],
                delay: Duration(milliseconds: i * 45),
                onTap: () {
                  onDismiss();
                  actions[i].onTap();
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Pops in with a spring-eased scale, staggered by [delay] so successive
/// fan buttons appear slightly after one another (mirrors the mockup's
/// per-index stagger). Collapses to an instant appearance when the
/// platform/user has reduced motion enabled.
class _FanActionButton extends StatefulWidget {
  const _FanActionButton({
    required this.action,
    required this.onTap,
    required this.delay,
  });

  final GlassNavQuickAction action;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_FanActionButton> createState() => _FanActionButtonState();
}

class _FanActionButtonState extends State<_FanActionButton> {
  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _appeared = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _appeared = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final shown = _appeared || reduced;

    return AnimatedScale(
      scale: shown ? 1.0 : 0.3,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      child: AnimatedOpacity(
        opacity: shown ? 1.0 : 0.0,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: widget.onTap,
            customBorder: const CircleBorder(),
            child: Semantics(
              label: widget.action.label,
              button: true,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Colors.white24),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black38,
                        blurRadius: 16,
                        offset: Offset(0, 6)),
                  ],
                ),
                child: Icon(widget.action.icon,
                    color: Theme.of(context).colorScheme.onSurface, size: 19),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/home/glass_bottom_nav_test.dart`
Expected: PASS (7 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/glass_bottom_nav.dart test/features/home/glass_bottom_nav_test.dart
git commit -m "feat(home): add PAD tap/long-press fan-out to GlassBottomNav"
```

---

### Task 4: Turn `ServicesHubTab` into an embeddable `ServicesGridSection`

**Files:**
- Delete: `lib/features/home/presentation/widgets/services_hub_tab.dart` (content moves to the new file below)
- Create: `lib/features/home/presentation/widgets/services_grid_section.dart`
- Test: `test/features/home/services_grid_section_test.dart`

**Interfaces:**
- Produces: `class ServicesGridSection extends StatelessWidget` (no required params) — a non-scrolling grid (`shrinkWrap`, `NeverScrollableScrollPhysics`) meant to be embedded inside another scrollable, unlike the old `ServicesHubTab` which was its own full-screen `CustomScrollView`. Consumed by Task 6 (`HomeView`'s Home tab).

- [ ] **Step 1: Write the failing test**

Create `test/features/home/services_grid_section_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/services_grid_section_test.dart`
Expected: FAIL — `package:mvvm_sip_demo/features/home/presentation/widgets/services_grid_section.dart` does not exist.

- [ ] **Step 3: Create the section widget**

Read the current `lib/features/home/presentation/widgets/services_hub_tab.dart` for the exact `_items`/`_ServiceCard`/`_ServiceItem` content (six services: Calling, Utility Bills, Payments, Providers, Call History, Order History), then create `lib/features/home/presentation/widgets/services_grid_section.dart` with that same content, restructured to be embeddable:

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/scale_tap_wrapper.dart';
import 'package:mvvm_sip_demo/shared/widgets/glide_card.dart';
import 'package:mvvm_sip_demo/shared/widgets/maintenance_screen.dart';

/// The services grid, embedded inside the Home tab's scroll view (it used
/// to be its own full-screen tab — see the glass-bottom-nav design spec for
/// why it moved).
class ServicesGridSection extends StatelessWidget {
  const ServicesGridSection({super.key});

  static const _items = <_ServiceItem>[
    _ServiceItem(
      icon: Icons.call_outlined,
      label: 'Calling',
      subtitle: 'Contacts & dialer',
      color: WunzaColors.glidePrimary,
      route: Routes.calling,
    ),
    _ServiceItem(
      icon: Icons.receipt_long_outlined,
      label: 'Utility Bills',
      subtitle: 'ZESA, water, council',
      color: Color(0xFF0288D1),
      route: Routes.utilityBills,
      underMaintenance: true,
    ),
    _ServiceItem(
      icon: Icons.payments_outlined,
      label: 'Payments',
      subtitle: 'Send & receive money',
      color: Color(0xFF2E7D32),
      route: Routes.payments,
      underMaintenance: true,
    ),
    _ServiceItem(
      icon: Icons.storefront_outlined,
      label: 'Providers',
      subtitle: 'Airtime, bundles, partners',
      color: WunzaColors.glideAccent,
      route: Routes.serviceProviders,
      underMaintenance: true,
    ),
    _ServiceItem(
      icon: Icons.history_toggle_off_outlined,
      label: 'Call History',
      subtitle: 'All recent calls',
      color: Color(0xFF5D4037),
      route: Routes.callHistory,
    ),
    _ServiceItem(
      icon: Icons.shopping_bag_outlined,
      label: 'Order History',
      subtitle: 'Track shop purchases',
      color: Color(0xFF6D4C41),
      route: Routes.orderHistory,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: _items.length,
      itemBuilder: (context, i) => _ServiceCard(item: _items[i]),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item});
  final _ServiceItem item;

  void _onTap(BuildContext context) {
    if (item.underMaintenance) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MaintenanceScreen(
            label: item.label,
            icon: item.icon,
            color: item.color,
          ),
        ),
      );
    } else {
      Navigator.pushNamed(context, item.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTapWrapper(
      onTap: () => _onTap(context),
      child: GlideCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 26),
                ),
                if (item.underMaintenance)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Soon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              item.label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              item.subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
    this.underMaintenance = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;
  final bool underMaintenance;
}
```

Then delete the old file:

```bash
git rm lib/features/home/presentation/widgets/services_hub_tab.dart
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/services_grid_section_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/services_grid_section.dart test/features/home/services_grid_section_test.dart
git commit -m "refactor(home): turn ServicesHubTab into embeddable ServicesGridSection"
```

(Note: `home_view.dart` still imports the old `services_hub_tab.dart` at this point — that's fixed in Task 6. The app will not compile between this task and Task 6 if built as a whole; each task's own test target still passes in isolation.)

---

### Task 5: `ExploreTab` placeholder discovery hub

**Files:**
- Create: `lib/features/home/presentation/widgets/explore_tab.dart`
- Test: `test/features/home/explore_tab_test.dart`

**Interfaces:**
- Produces: `class ExploreTab extends StatefulWidget` (no required params) — consumed by Task 6 (`HomeView`'s tab switch, index 1).

- [ ] **Step 1: Write the failing test**

Create `test/features/home/explore_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_tab.dart';

void main() {
  testWidgets('shows category chips and discovery sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExploreTab())));

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Trending now'), findsOneWidget);
    expect(find.text('Recommended for you'), findsOneWidget);
    expect(find.text('Nearby offers'), findsOneWidget);
    expect(find.text('Recently added'), findsOneWidget);
  });

  testWidgets('tapping a category chip switches the selected chip', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExploreTab())));

    await tester.tap(find.text('Trending'));
    await tester.pump();

    // No exception, chip row still renders after selection changes.
    expect(find.text('Trending'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/explore_tab_test.dart`
Expected: FAIL — `package:mvvm_sip_demo/features/home/presentation/widgets/explore_tab.dart` does not exist.

- [ ] **Step 3: Implement the placeholder Explore tab**

Create `lib/features/home/presentation/widgets/explore_tab.dart`:

```dart
import 'package:flutter/material.dart';

/// Placeholder discovery hub for the Explore tab. Content is static —
/// there's no backing data source yet (see the glass-bottom-nav design
/// spec's "Open items deferred" section). This is a structural port of
/// the GlassNav.jsx mockup's ExplorePage, not a new data feature.
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  static const _categories = ['All', 'Trending', 'Nearby', 'New', 'Events'];
  String _selected = 'All';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
      children: [
        Row(
          children: [
            Icon(Icons.explore_outlined,
                color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 8),
            Text('Explore', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = _categories[i];
              final selected = c == _selected;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => setState(() => _selected = c),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Trending now',
          icon: Icons.local_fire_department_outlined,
          items: const ['Wireless earbuds', 'Desk lamp', 'Running shoes'],
        ),
        _Section(
          title: 'Recommended for you',
          icon: Icons.auto_awesome_outlined,
          items: const [
            'Weekend picks',
            'Based on your shop history',
            'Similar to your saves',
          ],
        ),
        _RowSection(
          title: 'Nearby offers',
          icon: Icons.place_outlined,
          rows: const [
            ('Corner Cafe', '20% off, 0.3 mi away'),
            ('Green Market', 'Fresh produce, 0.8 mi away'),
          ],
        ),
        _RowSection(
          title: 'Recently added',
          icon: Icons.access_time_outlined,
          rows: const [
            ('New: Split payments', 'Send money together with friends'),
            ('New: Local events', 'Discover things happening near you'),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.items});

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Theme.of(context).hintColor),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _MediaCard(title: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color:
                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _RowSection extends StatelessWidget {
  const _RowSection(
      {required this.title, required this.icon, required this.rows});

  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Theme.of(context).hintColor),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          for (final (name, sub) in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Theme.of(context).textTheme.bodyLarge),
                        Text(sub,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/explore_tab_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/explore_tab.dart test/features/home/explore_tab_test.dart
git commit -m "feat(home): add placeholder ExploreTab discovery hub"
```

---

### Task 6: Wire `GlassBottomNav`/`ExploreTab`/`ServicesGridSection` into `HomeView`

**Files:**
- Modify: `lib/features/home/presentation/views/home_view.dart` (full-file rewrite of the sections listed below — see exact replacement content in Step 3)
- Delete: `lib/features/home/presentation/widgets/hanging_dialer.dart` (fully superseded by the PAD embedded in `GlassBottomNav`; only `home_view.dart` imported it)

**Interfaces:**
- Consumes: `GlassBottomNav`/`GlassNavTab`/`GlassNavQuickAction` (Task 2/3), `ServicesGridSection` (Task 4), `ExploreTab` (Task 5).

- [ ] **Step 1: Confirm no other references to the file being deleted**

Run: `grep -rn "hanging_dialer" lib`
Expected: only `lib/features/home/presentation/views/home_view.dart` (the import) — confirming it's safe to delete once that import is removed in Step 3.

- [ ] **Step 2: Manual/no automated test for this step — covered by existing app compile + Task 7's manual verification**

This task is a wiring change to an already-tested set of widgets (Tasks 2-5 each have their own passing widget tests). Correctness here is verified by (a) the project compiling (`flutter analyze`), and (b) the manual verification pass in Task 7. Writing a full `HomeView` widget test is out of scope — `HomeView` already pulls in DI (`getIt`), multiple `Provider`s, and network-backed view models that would require extensive mocking unrelated to this nav change.

- [ ] **Step 3: Rewrite `home_view.dart`**

Open `lib/features/home/presentation/views/home_view.dart` and replace its entire contents with:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/call_history_widget.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/views/dialpad_view.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_tab.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/glass_bottom_nav.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/scale_tap_wrapper.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/services_grid_section.dart';
import 'package:mvvm_sip_demo/shared/widgets/maintenance_screen.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/master_balance_card.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/promotions_carousel.dart';
import 'package:mvvm_sip_demo/features/profile/presentation/views/profile_view.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/shopping_view.dart';
import 'package:mvvm_sip_demo/shared/widgets/shimmer_widget.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;
  bool _navVisible = true;

  static const _tabs = [
    GlassNavTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    GlassNavTab(
        icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'Explore'),
    GlassNavTab(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront,
        label: 'Shop'),
    GlassNavTab(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<AccountSummaryViewModel>(context, listen: false)
          .loadCurrentUser();

      final creds = await getIt<OtpAuthService>().getStoredCredentials();
      final userId = creds?['username'] ?? 'guest';

      if (!mounted) return;

      Provider.of<DashboardViewModel>(context, listen: false)
          .loadDashboard(userId);
      Provider.of<ShoppingViewModel>(context, listen: false).loadCart(userId);

      final dialpad = Provider.of<DialpadViewModel>(context, listen: false);
      dialpad.loadRecents();
      dialpad.loadAccountInfo();
    });
  }

  void _onTabChange(int index) => setState(() => _currentIndex = index);

  void _openDialpadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: const DialpadView(),
      ),
    );
  }

  void _openMaintenance(
      {required String label, required IconData icon, required Color color}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceScreen(label: label, icon: icon, color: color),
      ),
    );
  }

  List<GlassNavQuickAction> _quickActions() => [
        GlassNavQuickAction(
          icon: Icons.send_outlined,
          label: 'Send',
          onTap: () => _openMaintenance(
            label: 'Send Money',
            icon: Icons.send_outlined,
            color: WunzaColors.glidePrimary,
          ),
        ),
        GlassNavQuickAction(
          icon: Icons.qr_code_scanner_outlined,
          label: 'Scan',
          onTap: () => _openMaintenance(
            label: 'Scan',
            icon: Icons.qr_code_scanner_outlined,
            color: WunzaColors.glideAccent,
          ),
        ),
        GlassNavQuickAction(
          icon: Icons.payments_outlined,
          label: 'Pay',
          onTap: () => _openMaintenance(
            label: 'Payments',
            icon: Icons.payments_outlined,
            color: const Color(0xFF2E7D32),
          ),
        ),
      ];

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse && _navVisible) {
      setState(() => _navVisible = false);
    } else if (notification.direction == ScrollDirection.forward &&
        !_navVisible) {
      setState(() => _navVisible = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [WunzaColors.glideNeutral, Color(0xFFE8E8ED)],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WunzaColors.glidePrimary.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onScrollNotification,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Container(
                  key: ValueKey<int>(_currentIndex),
                  child: _buildCurrentTab(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18 + MediaQuery.of(context).padding.bottom,
            child: Center(
              child: SizedBox(
                width: (MediaQuery.of(context).size.width - 28)
                    .clamp(0.0, 420.0)
                    .toDouble(),
                child: GlassBottomNav(
                  tabs: _tabs,
                  activeIndex: _currentIndex,
                  onTabSelected: _onTabChange,
                  onDialerTap: _openDialpadSheet,
                  quickActions: _quickActions(),
                  visible: _navVisible,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _GlideHomeTab(
          onGoShop: () => _onTabChange(2),
          onGoCart: () => Navigator.pushNamed(context, Routes.cart),
        );
      case 1:
        return const ExploreTab();
      case 2:
        return ShoppingView(onBack: () => _onTabChange(0));
      case 3:
        return const ProfileView(embeddedInMainShell: true);
      default:
        return _GlideHomeTab(
          onGoShop: () => _onTabChange(2),
          onGoCart: () => Navigator.pushNamed(context, Routes.cart),
        );
    }
  }
}

// ── Home tab ───────────────────────────────────────────────────────────────────

class _GlideHomeTab extends StatelessWidget {
  const _GlideHomeTab({
    required this.onGoShop,
    required this.onGoCart,
  });

  final VoidCallback onGoShop;
  final VoidCallback onGoCart;

  @override
  Widget build(BuildContext context) {
    return Consumer3<ShoppingViewModel, AccountSummaryViewModel,
        DialpadViewModel>(
      builder: (context, shoppingVM, accountVM, dialpadVM, _) {
        final cartCount = (shoppingVM.cart['items'] as List?)?.length ?? 0;
        final alias = accountVM.alias ?? '…';
        final mq = MediaQuery.of(context);
        final h = (mq.size.width * 0.05).clamp(16.0, 22.0).toDouble();

        final pb = accountVM.paymentsBalance;
        final pbLoading = accountVM.paymentsLoading;
        final voiceMins = accountVM.formattedMinutes;
        final walletKey = '${pb ?? voiceMins}_$alias';
        final walletPrimary = pbLoading
            ? '…'
            : pb != null
                ? '\$${NumberFormat('#,##0.00', 'en_US').format(pb)}'
                : voiceMins;
        final walletChipText = (accountVM.loading && accountVM.alias == null) ||
                pbLoading
            ? 'Wallet · …'
            : pb != null
                ? 'Wallet · \$${NumberFormat('#,##0.00', 'en_US').format(pb)}'
                : 'Balance · $voiceMins';

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeTopBar(
                userName: accountVM.loading && accountVM.alias == null
                    ? '…'
                    : alias,
                walletChipLabel: accountVM.loading && accountVM.alias == null
                    ? 'Loading…'
                    : walletChipText,
                notificationCount: cartCount,
                onNotificationsTap: onGoCart,
                onAvatarTap: () => Navigator.pushNamed(context, Routes.profile),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (accountVM.loading && accountVM.alias == null)
                      const ShimmerWidget.rectangular(
                          height: 180, width: double.infinity)
                    else
                      GestureDetector(
                        onLongPress: () => accountVM.loadCurrentUser(),
                        child: MasterBalanceCard(
                          walletBalanceKey: walletKey,
                          walletBalanceText: walletPrimary,
                          voiceChipLabel: _voiceChipLabel(accountVM.balance),
                          dataChipLabel: 'Data — add a bundle',
                          onTopUp: () => _launchTopUp(context),
                          onManageAccount: () =>
                              Navigator.pushNamed(context, Routes.profile),
                        ),
                      ),
                    const SizedBox(height: 28),
                    _QuickServicesRow(onGoShop: onGoShop),
                    const SizedBox(height: 28),
                    Text('All services',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const ServicesGridSection(),
                    const SizedBox(height: 28),
                    GlidePromotionsCarousel(
                        apiBanners: shoppingVM.banners,
                        onBannerTap: (_) => onGoShop()),
                    const SizedBox(height: 28),
                    const CallHistoryWidget(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Quick services row ─────────────────────────────────────────────────────────

class _QuickServicesRow extends StatelessWidget {
  const _QuickServicesRow({required this.onGoShop});

  final VoidCallback onGoShop;

  @override
  Widget build(BuildContext context) {
    final actions = <_QA>[
      _QA(
        icon: Icons.call_outlined,
        label: 'Call',
        color: WunzaColors.glidePrimary,
        onTap: () => Navigator.pushNamed(context, Routes.calling),
      ),
      _QA(
        icon: Icons.storefront_outlined,
        label: 'Shop',
        color: WunzaColors.glideAccent,
        onTap: onGoShop,
      ),
      _QA(
        icon: Icons.receipt_long_outlined,
        label: 'Bills',
        color: const Color(0xFF0288D1),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MaintenanceScreen(
              label: 'Utility Bills',
              icon: Icons.receipt_long_outlined,
              color: Color(0xFF0288D1),
            ),
          ),
        ),
      ),
      _QA(
        icon: Icons.payments_outlined,
        label: 'Pay',
        color: const Color(0xFF2E7D32),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MaintenanceScreen(
              label: 'Payments',
              icon: Icons.payments_outlined,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ),
      _QA(
        icon: Icons.history_outlined,
        label: 'History',
        color: const Color(0xFF5D4037),
        onTap: () => Navigator.pushNamed(context, Routes.callHistory),
      ),
      _QA(
        icon: Icons.manage_accounts_outlined,
        label: 'Account',
        color: const Color(0xFF7B1FA2),
        onTap: () => Navigator.pushNamed(context, Routes.profile),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick services', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) => _QuickActionTile(qa: actions[i]),
          ),
        ),
      ],
    );
  }
}

class _QA {
  const _QA({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.qa});
  final _QA qa;

  @override
  Widget build(BuildContext context) {
    return ScaleTapWrapper(
      onTap: qa.onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: qa.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: qa.color.withValues(alpha: 0.18), width: 1),
              ),
              child: Icon(qa.icon, color: qa.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              qa.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _voiceChipLabel(double? balanceNs) {
  final raw = _formatVoiceBalance(balanceNs ?? 0);
  return raw.replaceAll('Voice Bal: ', 'Minutes · ');
}

Future<void> _launchTopUp(BuildContext context) async {
  const url = 'https://selfservice.ai.co.zw/';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}

String _formatVoiceBalance(double nanoseconds) {
  if (nanoseconds <= 0) return 'Voice Bal: 0 m';
  final duration = Duration(microseconds: (nanoseconds / 1000).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return 'Voice Bal: $hours hrs $minutes m';
  return 'Voice Bal: $minutes m $seconds s';
}
```

Note `ScrollDirection` (used in `_onScrollNotification`) comes from `package:flutter/material.dart`'s re-export of `package:flutter/widgets.dart` — no extra import needed.

Then delete the now-unused FAB widget:

```bash
git rm lib/features/home/presentation/widgets/hanging_dialer.dart
```

- [ ] **Step 4: Verify the project compiles and all widget tests still pass**

Run: `flutter analyze lib/features/home`
Expected: "No issues found!" (or only pre-existing issues unrelated to files touched in this plan).

Run: `flutter test test/features/home`
Expected: PASS — all tests from Tasks 2-5 still pass unmodified.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/views/home_view.dart
git commit -m "feat(home): wire GlassBottomNav, ExploreTab, and ServicesGridSection into HomeView"
```

---

### Task 7: Manual verification

**Files:** none (verification only).

- [ ] **Step 1: Run the app**

Run: `flutter run` (or use this project's `/run` skill if available) on a simulator/device/emulator, logged in with test credentials.

- [ ] **Step 2: Exercise the nav**

Check each of the following and confirm it matches the design spec (`docs/superpowers/specs/2026-07-07-glass-bottom-nav-design.md`):
- Tapping Home/Explore/Shop/Profile switches tabs and the violet indicator slides to the tapped tab.
- Home tab shows the balance card, Quick services row, the full "All services" grid (all 6 items, same destinations as the old Services tab), promotions, and recent activity.
- Short tap on the center PAD opens the dialpad bottom sheet (unchanged from before).
- Long-press on the PAD fans open Send/Scan/Pay; tapping any of them opens the "Coming soon" maintenance screen; tapping the dimmed scrim closes the fan without navigating.
- Scrolling down on the Home tab hides the nav; scrolling up (or reaching the top) brings it back.
- Toggling light/dark mode from Profile updates the nav's glass tint correctly in both modes.

- [ ] **Step 3: Confirm no regressions in previously-Services-only destinations**

From the new "All services" grid on Home, confirm `Calling`, `Call History`, and `Order History` still navigate correctly (these were the non-maintenance-placeholder items), and `Utility Bills`/`Payments`/`Providers` still show their "Coming soon" screen (unchanged behavior, just relocated).

- [ ] **Step 4: Record results**

If everything above passes, this plan is complete — no commit needed for this task (verification-only).
If something fails, note which step and behavior, then fix forward with a new commit before considering the plan done.
