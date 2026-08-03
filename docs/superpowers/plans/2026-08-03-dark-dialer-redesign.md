# Dark Dialer UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `DialpadView` (the bottom-sheet dialer opened from Home) to match a dark gradient/glass reference design, trim its internal nav from 4 tabs to 3 (Recents/Contacts/Market Place), and enhance the already-real device-contacts integration in `ContactsView` (permission states, sorting, pull-to-refresh, matching dark visuals).

**Architecture:** `DialpadView` owns a new full-bleed gradient background and a rounded glass panel (both extracted into small reusable widgets so `ContactsView`'s dark variant can share them); a new `_DialerSection` enum (keypad/recents/contacts) replaces the old 4-way tab index; a new purpose-built `DialerGlassNav` widget (3 tabs, no PAD) replaces the plain white `BottomNavigationBar`; Market Place taps close the sheet and navigate to the existing `Routes.shopping`. `ContactsView` is shared with `CallingView` (a different, out-of-scope screen), so its visual restyle is gated behind a `darkTheme` constructor flag defaulting to `false` — `CallingView`'s embed is completely unaffected — while the permission/sorting/refresh functional improvements apply unconditionally to both call sites.

**Tech Stack:** Flutter/Dart, Provider + get_it (existing DI), `flutter_contacts` + `permission_handler` (both already `pubspec.yaml` dependencies), `sip_ua` (untouched call logic).

## Global Constraints

- Background gradient: `#2A1F4D` (top) → `#0B0A17` (bottom), top-to-bottom.
- Glass panel: `BorderRadius.circular(32)`, fill `rgba(255,255,255,0.04)` = `Color(0x0AFFFFFF)`.
- Keypad button fill: `rgba(255,255,255,0.08)` = `Color(0x14FFFFFF)`, circular, no border.
- Active nav tab accent: cyan/teal `#4DD8E0`.
- Call button: purple→blue diagonal gradient, composed from the two **existing** `WunzaColors.indigo` (`#4F46E5`) and `WunzaColors.blueAccent` (`#3B82F6`) tokens — do not invent new raw hex for this, reuse the established brand colors.
- `CallingView`, `HelpSupportView`, `SipCallManager`, `Routes`, and `DialpadViewModel`'s balance/recents/call-placing logic are **untouched** by every task in this plan.
- No DTMF tone playback is added — none exists today, out of scope.
- `.claude/settings.json` and `assets/icon/icon.png` are pre-existing, unrelated, uncommitted local files in this repo's working tree. Never stage, commit, or revert them. Use `git add <specific files>` in every commit step below — never `git add -A` or `git add .`.
- Verification per task: `/home/user/snap/flutter/common/flutter/bin/dart analyze` (use this exact real Flutter SDK binary — `/snap/bin/dart` silently misbehaves in this sandbox) plus the task's own focused test file(s). Do not run the full `flutter test` suite or `flutter build` — rejected multiple times this session; this is the established verification method.
- Full spec: `docs/superpowers/specs/2026-08-03-dark-dialer-redesign-design.md`.

---

### Task 1: Theme tokens + shared gradient/panel widgets

**Files:**
- Modify: `lib/core/theme.dart`
- Create: `lib/features/dialpad/presentation/widgets/dialer_gradient_background.dart`
- Test: `test/features/dialpad/presentation/widgets/dialer_gradient_background_test.dart`

**Interfaces:**
- Produces: `WunzaColors.dialerBackgroundGradient` (`LinearGradient`), `WunzaColors.dialerPanelFill` (`Color`), `WunzaColors.dialerKeypadFill` (`Color`), `WunzaColors.dialerNavActive` (`Color`), `WunzaColors.dialerCallGradient` (`LinearGradient`); `DialerGradientBackground({required Widget child})`; `GlassPanelContainer({required Widget child, EdgeInsets margin = ...})`.

- [ ] **Step 1: Add the new color/gradient tokens to `theme.dart`**

Open `lib/core/theme.dart`. Immediately after the existing "Glass bottom nav tokens" block (after the line `static const Color padGradientEnd = Color(0xFFFF4D6D); // pink`, still inside `class WunzaColors { ... }`, before its closing `}`), add:

```dart

  // --- Dark dialer redesign tokens (dialer + contacts dark variant only) ---
  static const LinearGradient dialerBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A1F4D), Color(0xFF0B0A17)],
  );
  static const Color dialerPanelFill = Color(0x0AFFFFFF); // rgba(255,255,255,0.04)
  static const Color dialerKeypadFill = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color dialerNavActive = Color(0xFF4DD8E0); // cyan/teal
  static const LinearGradient dialerCallGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo, blueAccent],
  );
```

- [ ] **Step 2: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/core/theme.dart`
Expected: `No issues found!`

- [ ] **Step 3: Create the shared background/panel widgets**

Create `lib/features/dialpad/presentation/widgets/dialer_gradient_background.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

/// Full-bleed dark gradient background shared by the redesigned dialer and
/// (when its `darkTheme` flag is on) the contacts screen, so both read as
/// one continuous surface.
class DialerGradientBackground extends StatelessWidget {
  const DialerGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: WunzaColors.dialerBackgroundGradient,
      ),
      child: child,
    );
  }
}

/// Rounded translucent "glass" panel used to house the dialer keypad over
/// [DialerGradientBackground].
class GlassPanelContainer extends StatelessWidget {
  const GlassPanelContainer({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(20, 20, 20, 0),
  });

  final Widget child;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: WunzaColors.dialerPanelFill,
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
```

- [ ] **Step 4: Write the smoke test**

Create `test/features/dialpad/presentation/widgets/dialer_gradient_background_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/widgets/dialer_gradient_background.dart';

void main() {
  testWidgets('DialerGradientBackground paints the gradient and shows its child',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DialerGradientBackground(
          child: Center(child: Text('inner content')),
        ),
      ),
    );

    expect(find.text('inner content'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.decoration, isA<BoxDecoration>());
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);
  });

  testWidgets('GlassPanelContainer renders rounded translucent panel with its child',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassPanelContainer(
          child: Center(child: Text('panel content')),
        ),
      ),
    );

    expect(find.text('panel content'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(32));
  });
}
```

- [ ] **Step 5: Run the test**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/dialpad/presentation/widgets/dialer_gradient_background_test.dart`
Expected: both tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme.dart lib/features/dialpad/presentation/widgets/dialer_gradient_background.dart test/features/dialpad/presentation/widgets/dialer_gradient_background_test.dart
git commit -m "feat(dialer): add dark redesign color tokens and shared gradient/panel widgets"
```

---

### Task 2: `DialerGlassNav` widget

**Files:**
- Create: `lib/features/dialpad/presentation/widgets/dialer_glass_nav.dart`
- Test: `test/features/dialpad/presentation/widgets/dialer_glass_nav_test.dart`

**Interfaces:**
- Consumes: `WunzaColors.navGlassDark` (existing token), `WunzaColors.dialerNavActive` (from Task 1).
- Produces: `DialerGlassNav({required int activeIndex, required ValueChanged<int> onTabSelected, required VoidCallback onMarketPlaceTap})`. `activeIndex`: `0` = Recents, `1` = Contacts. Market Place (visually index 2) never becomes "active" — tapping it only invokes `onMarketPlaceTap`, never `onTabSelected`.

- [ ] **Step 1: Write the widget**

Create `lib/features/dialpad/presentation/widgets/dialer_glass_nav.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

/// The 3-tab floating glass nav bar shown at the bottom of the redesigned
/// dialer sheet: Recents, Contacts, Market Place.
///
/// This is deliberately a separate, smaller widget from Home's own
/// `GlassBottomNav` — that widget assumes exactly 4 tabs plus a centered
/// dial-PAD button (see its own doc comment), which doesn't fit this
/// screen (already inside the dialer; no PAD needed). Both widgets share
/// the same [WunzaColors] tokens for visual consistency.
class DialerGlassNav extends StatelessWidget {
  const DialerGlassNav({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onMarketPlaceTap,
  });

  /// 0 = Recents, 1 = Contacts.
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onMarketPlaceTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      decoration: BoxDecoration(
        color: WunzaColors.navGlassDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Row(
          children: [
            Expanded(
              child: _NavTabButton(
                icon: Icons.access_time_outlined,
                activeIcon: Icons.access_time_filled,
                label: 'Recents',
                isActive: activeIndex == 0,
                onTap: () => onTabSelected(0),
              ),
            ),
            Expanded(
              child: _NavTabButton(
                icon: Icons.contacts_outlined,
                activeIcon: Icons.contacts,
                label: 'Contacts',
                isActive: activeIndex == 1,
                onTap: () => onTabSelected(1),
              ),
            ),
            Expanded(
              child: _NavTabButton(
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront,
                label: 'Market Place',
                isActive: false,
                onTap: onMarketPlaceTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? WunzaColors.dialerNavActive : Colors.white54;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write the tests**

Create `test/features/dialpad/presentation/widgets/dialer_glass_nav_test.dart`:

```dart
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
```

- [ ] **Step 3: Run the tests**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/dialpad/presentation/widgets/dialer_glass_nav_test.dart`
Expected: all 4 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dialpad/presentation/widgets/dialer_glass_nav.dart test/features/dialpad/presentation/widgets/dialer_glass_nav_test.dart
git commit -m "feat(dialer): add DialerGlassNav 3-tab widget"
```

---

### Task 3: `groupContactsByLetter` pure function

**Files:**
- Create: `lib/features/contacts/data/utils/contact_grouping.dart`
- Test: `test/features/contacts/data/utils/contact_grouping_test.dart`

**Interfaces:**
- Produces: `Map<String, List<Contact>> groupContactsByLetter(List<Contact> contacts)` — sorts by `displayName` (case-insensitive), groups by uppercased first letter (`'#'` for an empty `displayName`). Consumed by Task 8.

**Context:** `Contact` (from `package:flutter_contacts/flutter_contacts.dart`, already pinned at `1.1.9+2`) has a plain constructor `Contact({this.displayName = '', ...})` with a directly settable `String displayName` field — verified against the real package source, so it's freely constructible in this test without any platform channel or mock.

- [ ] **Step 1: Write the failing test**

Create `test/features/contacts/data/utils/contact_grouping_test.dart`:

```dart
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/contacts/data/utils/contact_grouping.dart';

void main() {
  group('groupContactsByLetter', () {
    test('sorts case-insensitively and groups by first letter', () {
      final contacts = [
        Contact(displayName: 'bob'),
        Contact(displayName: 'Alice'),
        Contact(displayName: 'anna'),
        Contact(displayName: 'Charlie'),
      ];

      final grouped = groupContactsByLetter(contacts);

      expect(grouped.keys.toList(), ['A', 'B', 'C']);
      expect(grouped['A']!.map((c) => c.displayName), ['Alice', 'anna']);
      expect(grouped['B']!.map((c) => c.displayName), ['bob']);
      expect(grouped['C']!.map((c) => c.displayName), ['Charlie']);
    });

    test('groups an empty displayName under "#"', () {
      final contacts = [Contact(displayName: '')];
      final grouped = groupContactsByLetter(contacts);
      expect(grouped.keys.toList(), ['#']);
    });

    test('returns an empty map for an empty list', () {
      expect(groupContactsByLetter(const []), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/contacts/data/utils/contact_grouping_test.dart`
Expected: FAIL — `contact_grouping.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/contacts/data/utils/contact_grouping.dart`:

```dart
import 'package:flutter_contacts/flutter_contacts.dart';

/// Sorts [contacts] alphabetically by display name (case-insensitive) and
/// groups them by uppercased first letter, for section-header rendering.
/// Pure and side-effect-free so it's testable without a live
/// device-contacts call.
Map<String, List<Contact>> groupContactsByLetter(List<Contact> contacts) {
  final sorted = [...contacts]
    ..sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

  final grouped = <String, List<Contact>>{};
  for (final contact in sorted) {
    final letter =
        contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '#';
    grouped.putIfAbsent(letter, () => []).add(contact);
  }
  return grouped;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/contacts/data/utils/contact_grouping_test.dart`
Expected: all 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/contacts/data/utils/contact_grouping.dart test/features/contacts/data/utils/contact_grouping_test.dart
git commit -m "feat(contacts): add pure groupContactsByLetter helper"
```

---

### Task 4: Restyle `RecentsView` to dark theme

**Files:**
- Modify: `lib/features/recents/presentation/views/recents_view.dart`

**Context:** Verified via `grep -rl "RecentsView" lib/` that this specific file's `RecentsView` class has exactly one caller — `DialpadView` (`lib/features/dialpad/presentation/views/dialpad_view.dart`). `CallingView` uses a different, separately-named-but-distinct `RecentsView` class from `lib/features/calling/presentation/views/tabs/recents_view.dart` — a different file entirely. So this file can be fully, unconditionally restyled with zero risk to `CallingView` — no flag/parameter needed, unlike `ContactsView` in Tasks 8–9.

Once Task 5 lands, this widget will be shown directly inside `DialpadView`'s own `GlassPanelContainer` — so it no longer needs its own `Scaffold` (which only ever set a background color, no `AppBar`); it becomes a plain widget that inherits the panel's background.

- [ ] **Step 1: Rewrite the file**

Replace the full contents of `lib/features/recents/presentation/views/recents_view.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../dialpad/presentation/viewmodels/dialpad_viewmodel.dart';

class RecentsView extends StatelessWidget {
  const RecentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DialpadViewModel>(
      builder: (context, viewModel, child) {
        final recents = viewModel.recents;

        if (recents.isEmpty) {
          return const Center(
            child: Text(
              'No recent calls',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: recents.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = recents[index];
            final isMissed = item.isMissed;
            final timeString =
                DateFormat('MMM d, h:mm a').format(item.timestamp);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isMissed
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : Colors.greenAccent.withValues(alpha: 0.15),
                    child: Icon(
                      isMissed ? Icons.call_missed : Icons.call_made,
                      color: isMissed ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name ?? item.number,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        if (item.name != null)
                          Text(
                            item.number,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    timeString,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/features/recents/presentation/views/recents_view.dart`
Expected: `No issues found!`

This is a visual-only restyle of already-tested data logic (`viewModel.recents`, `item.isMissed`/`.name`/`.number`/`.timestamp` are all unchanged reads); per this session's established testing precedent (e.g. `call_history_widget.dart` has no dedicated widget test), no new test is added here — verified by `dart analyze` plus manual verification once Task 5 wires it in.

- [ ] **Step 3: Commit**

```bash
git add lib/features/recents/presentation/views/recents_view.dart
git commit -m "style(dialer): restyle RecentsView to dark theme"
```

---

### Task 5: Redesign `DialpadView`

**Files:**
- Modify: `lib/features/dialpad/presentation/views/dialpad_view.dart`

**Interfaces:**
- Consumes: `DialerGradientBackground`, `GlassPanelContainer` (Task 1); `DialerGlassNav` (Task 2); `WunzaColors.dialerCallGradient`/`dialerKeypadFill` (Task 1); `RecentsView` (Task 4, dark-restyled); `Routes.shopping` (existing, `lib/core/routes.dart`).
- Produces: no new public API — this is a leaf screen. Internal `enum _DialerSection { keypad, recents, contacts }` replaces the old `int _selectedIndex`.

**Context:** This task changes the visual layer, the screen-state model, and the nav wiring. It does **not** change `_handleCall`, `_showAlert`, `_handleBackSpace`, `_handleNum`, `_updateRegistrationStatus`, `_sipStatusColor`, or any `SipUaHelperListener` override body — those are copied verbatim from the current file.

- [ ] **Step 1: Replace the full contents of `dialpad_view.dart`**

Replace the full contents of `lib/features/dialpad/presentation/views/dialpad_view.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import '../viewmodels/dialpad_viewmodel.dart';
import '../../../../core/di/inject.dart';
import '../../../../core/routes.dart';
import '../../../../core/theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/sip_utils.dart';
import '../../../call/presentation/views/call_view.dart';
import '../../../recents/presentation/views/recents_view.dart';
import '../../../contacts/presentation/views/contacts_view.dart';
import '../widgets/dialer_gradient_background.dart';
import '../widgets/dialer_glass_nav.dart';

enum _DialerSection { keypad, recents, contacts }

class DialpadView extends StatefulWidget {
  const DialpadView({super.key});

  @override
  State<DialpadView> createState() => _DialpadViewState();
}

class _DialpadViewState extends State<DialpadView>
    implements SipUaHelperListener {
  late DialpadViewModel _viewModel;
  late SIPUAHelper _sipHelper;
  final TextEditingController _textController = TextEditingController();

  _DialerSection _section = _DialerSection.keypad;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<DialpadViewModel>();
    _sipHelper = getIt<SIPUAHelper>();
    _sipHelper.addSipUaHelperListener(this);
    _updateRegistrationStatus();
    _viewModel.loadAccountInfo();
    _viewModel.loadRecents();
  }

  @override
  void dispose() {
    _textController.dispose();
    _sipHelper.removeSipUaHelperListener(this);
    super.dispose();
  }

  void _updateRegistrationStatus() {
    final state = _sipHelper.registerState.state?.name ?? '';
    _viewModel.updateRegistrationStatus(state);
  }

  Color _sipStatusColor(DialpadViewModel viewModel) {
    if (viewModel.isSipReady) return Colors.green;
    if (_sipHelper.connecting) {
      return Colors.orange;
    }
    return Colors.red;
  }

  Future<void> _handleCall(bool voiceOnly) async {
    final dest = _textController.text;
    if (dest.isEmpty) {
      _showAlert('Target is empty.', 'Please enter a SIP URI or username!');
      return;
    }

    await _viewModel.saveDestination(dest);

    final result = await SipUtils.placeOutgoingCall(
      _sipHelper,
      dest,
      voiceOnly: voiceOnly,
    );
    if (result is Failure && mounted) {
      _showAlert('Cannot place call', result.message);
    }
  }

  void _showAlert(String title, String content) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleBackSpace([bool deleteAll = false]) {
    var text = _textController.text;
    if (text.isNotEmpty) {
      setState(() {
        text = deleteAll ? '' : text.substring(0, text.length - 1);
        _textController.text = text;
        _viewModel.setDestination(text);
      });
    }
  }

  void _handleNum(String number) {
    setState(() {
      _textController.text += number;
      _viewModel.addDigit(number);
    });
  }

  void _onNavTabSelected(int index) {
    setState(() {
      _section =
          index == 1 ? _DialerSection.contacts : _DialerSection.recents;
    });
  }

  void _onMarketPlaceTap() {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(Routes.shopping);
  }

  Widget _buildBody(DialpadViewModel viewModel) {
    switch (_section) {
      case _DialerSection.keypad:
        return _buildDialpadScreen(viewModel);
      case _DialerSection.recents:
        return const RecentsView();
      case _DialerSection.contacts:
        return const ContactsView(darkTheme: true);
    }
  }

  Widget _buildTopBar(DialpadViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          _GhostIconButton(
            icon: Icons.search,
            onTap: () {
              // Search functionality or focus search bar
            },
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _sipStatusColor(viewModel),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        "Voice Bal: ${viewModel.voiceBalance}",
                        key: ValueKey<String>('voice_${viewModel.voiceBalance}'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    "Balance: ${viewModel.accountBalance}",
                    key: ValueKey<String>('account_${viewModel.accountBalance}'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert, color: Colors.white70, size: 22),
            ),
            color: const Color(0xFF1E1E2E),
            onSelected: (String value) {
              switch (value) {
                case 'account':
                  Navigator.pushNamed(context, '/account');
                  break;
                case 'about':
                  Navigator.pushNamed(context, '/about');
                  break;
                case 'refresh':
                  viewModel.loadAccountInfo();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'account',
                child: Text('Account', style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'about',
                child: Text('About', style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialpadScreen(DialpadViewModel viewModel) {
    final hasDigits = _textController.text.isNotEmpty;
    return Column(
      children: [
        const SizedBox(height: 12),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            hasDigits ? _textController.text : 'Enter number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.2,
              color: hasDigits ? Colors.white : Colors.white38,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: _buildNumPadGrid()),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _handleCall(true),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: WunzaColors.dialerCallGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: WunzaColors.blueAccent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call, color: Colors.white, size: 32),
                ),
              ),
              if (hasDigits) ...[
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _handleBackSpace(),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: WunzaColors.dialerKeypadFill,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.backspace_outlined,
                        color: Colors.white54, size: 22),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<DialpadViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: DialerGradientBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: GlassPanelContainer(
                        child: Column(
                          children: [
                            _buildTopBar(viewModel),
                            Expanded(child: _buildBody(viewModel)),
                          ],
                        ),
                      ),
                    ),
                    DialerGlassNav(
                      activeIndex:
                          _section == _DialerSection.contacts ? 1 : 0,
                      onTabSelected: _onNavTabSelected,
                      onMarketPlaceTap: _onMarketPlaceTap,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildNumPadGrid() {
    final labels = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    final subLabels = {
      '1': '', '2': 'ABC', '3': 'DEF',
      '4': 'GHI', '5': 'JKL', '6': 'MNO',
      '7': 'PQRS', '8': 'TUV', '9': 'WXYZ',
      '*': '', '0': '+', '#': ''
    };

    return labels.map((row) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            return _buildKeypadButton(key, subLabels[key] ?? '');
          }).toList(),
        ),
      );
    }).toList();
  }

  Widget _buildKeypadButton(String label, String sub) {
    return InkWell(
      onTap: () => _handleNum(label),
      borderRadius: BorderRadius.circular(44),
      child: Container(
        height: 72,
        width: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: WunzaColors.dialerKeypadFill,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    _viewModel.updateRegistrationStatus(state.state?.name ?? '');
    if (mounted) setState(() {});
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void callStateChanged(Call call, CallState callState) {
    switch (callState.state) {
      case CallStateEnum.CALL_INITIATION:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallView(call: call),
          ),
        );
        break;
      case CallStateEnum.FAILED:
      case CallStateEnum.ENDED:
        break;
      default:
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    String? msgBody = msg.request.body as String?;
    _viewModel.updateReceivedMessage(msgBody ?? '');
  }

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
    );
  }
}
```

This task's `_buildBody` references `ContactsView(darkTheme: true)`. That constructor parameter doesn't exist on `ContactsView` yet — Step 2 below adds a minimal stub for it now (accepted but not yet visually acted on) so this task compiles standalone; Task 9 gives it real dark-styling behavior later.

- [ ] **Step 2: Add a minimal `darkTheme` parameter to `ContactsView`**

In `lib/features/contacts/presentation/views/contacts_view.dart`, change:

```dart
class ContactsView extends StatefulWidget {
  const ContactsView({super.key});
```

to:

```dart
class ContactsView extends StatefulWidget {
  const ContactsView({super.key, this.darkTheme = false});

  /// When true, renders with the dark glass styling used inside the
  /// redesigned dialer sheet. Defaults to false so this widget's other
  /// caller (CallingView's Contacts tab) is completely unaffected until
  /// Task 9 gives this flag real visual behavior — for now it is accepted
  /// but not yet acted on.
  final bool darkTheme;
```

No other change to this file in this task — `widget.darkTheme` is read directly wherever needed once Task 9 lands.

- [ ] **Step 3: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/features/dialpad/presentation/views/dialpad_view.dart lib/features/contacts/presentation/views/contacts_view.dart`
Expected: `No issues found!`

- [ ] **Step 4: Run the existing focused test suite to confirm no regression**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/dialpad/presentation/widgets/`
Expected: all tests from Tasks 1–2 still PASS (this task doesn't modify those files).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dialpad/presentation/views/dialpad_view.dart lib/features/contacts/presentation/views/contacts_view.dart
git commit -m "feat(dialer): redesign DialpadView with dark gradient/glass visuals and 3-tab nav"
```

---

### Task 6: Update `home_view.dart`'s sheet container

**Files:**
- Modify: `lib/features/home/presentation/views/home_view.dart`

**Context:** `DialpadView` now paints its own full-bleed gradient and owns the rounded-panel look internally (Task 5). The wrapping `Container` in `_openDialpadSheet` should stop painting an opaque white background (which would otherwise sit uselessly behind — or, since it currently isn't clipped, would show square corners over — the new gradient) and should properly clip `DialpadView`'s content to the intended rounded-top shape, which it currently does not do (`Container` doesn't clip a `child` to its `decoration`'s shape unless `clipBehavior` is set — verified: no `clipBehavior` is set today).

- [ ] **Step 1: Update `_openDialpadSheet`**

In `lib/features/home/presentation/views/home_view.dart`, change:

```dart
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
```

to:

```dart
  void _openDialpadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: const DialpadView(),
      ),
    );
  }
```

(`decoration.color` is dropped entirely rather than set to `Colors.transparent` — an undecorated `BoxDecoration` with no `color` paints nothing, which is what's wanted; `DialpadView`'s own gradient fills the visible area, and `clipBehavior: Clip.antiAlias` makes the rounded-top shape actually clip that gradient instead of being drawn under a square child.)

- [ ] **Step 2: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/features/home/presentation/views/home_view.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/views/home_view.dart
git commit -m "fix(home): clip the dialer sheet to its rounded shape so the new gradient shows correctly"
```

---

### Task 7: Delete the orphaned Speed Test view

**Files:**
- Delete: `lib/features/speed_test/presentation/views/speed_test_view.dart`

**Context:** Task 5 removed `DialpadView`'s only import of this file (the old `case 3: return const SpeedTestView();` branch and its import are both gone). Verify via grep before deleting that no other reference exists — `CallingView` uses a distinct file, `lib/features/calling/presentation/views/tabs/speed_test_view.dart`, which is untouched.

- [ ] **Step 1: Confirm the file is orphaned**

Run: `grep -rn "features/speed_test/presentation/views/speed_test_view.dart\|import.*speed_test/presentation/views/speed_test_view" lib/ test/`
Expected: no output (zero matches) — confirming nothing references this exact file anymore.

- [ ] **Step 2: Delete the file**

```bash
git rm lib/features/speed_test/presentation/views/speed_test_view.dart
```

- [ ] **Step 3: Verify the repo still analyzes cleanly**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze`
Expected: no new issues introduced by the deletion (a missing-file/import error would show up here if something was missed in Step 1).

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(dialer): delete orphaned speed_test_view.dart"
```

(The `git rm` in Step 2 already stages the deletion — no separate `git add` needed.)

---

### Task 8: `ContactsView` — permission states, sorting, pull-to-refresh

**Files:**
- Modify: `lib/features/contacts/presentation/views/contacts_view.dart`

**Interfaces:**
- Consumes: `groupContactsByLetter` (Task 3); `Permission.contacts` / `PermissionStatus.isGranted`/`.isPermanentlyDenied` / `openAppSettings()` (from `permission_handler`, already a dependency — verified against the pinned `12.0.1` source: `Permission.contacts.status` returns a `Future<PermissionStatus>`, and `PermissionStatus` exposes synchronous `isGranted`/`isDenied`/`isPermanentlyDenied` getters).
- Produces: no change to the `darkTheme` flag's visual behavior yet (that's Task 9) — this task is functional only, keeping the current light Material visuals unchanged so this task's diff is reviewable independently of Task 9's visual changes.

**Context:** Existing tap-to-call/copy-to-dialpad bottom sheet behavior (`_onContactTapped`/`_showContactOptions`) is preserved verbatim — the user asked to match existing tap behavior exactly.

- [ ] **Step 1: Replace the full contents of `contacts_view.dart`**

Replace the full contents of `lib/features/contacts/presentation/views/contacts_view.dart` with:

```dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/di/inject.dart';
import '../../../call/presentation/viewmodels/call_viewmodel.dart';
import '../../../dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import '../../data/utils/contact_grouping.dart';

enum _ContactsPermissionState { unknown, granted, denied, permanentlyDenied }

class ContactsView extends StatefulWidget {
  const ContactsView({super.key, this.darkTheme = false});

  /// When true, renders with the dark glass styling used inside the
  /// redesigned dialer sheet. Defaults to false so CallingView's Contacts
  /// tab (the other caller of this widget) is unaffected.
  final bool darkTheme;

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  List<Contact>? _contacts;
  List<Contact>? _filteredContacts;
  _ContactsPermissionState _permissionState = _ContactsPermissionState.unknown;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_contacts != null) {
        _filteredContacts = _contacts!.where((contact) {
          final nameMatches =
              contact.displayName.toLowerCase().contains(_searchQuery);
          final phoneMatches = contact.phones.any((phone) => phone.number
              .replaceAll(RegExp(r'[^\d+]'), '')
              .contains(_searchQuery));
          return nameMatches || phoneMatches;
        }).toList();
      }
    });
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _contacts = null;
      _permissionState = _ContactsPermissionState.unknown;
    });

    bool isMobile = false;
    try {
      isMobile = Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      isMobile = false;
    }

    if (!isMobile) {
      setState(() {
        _contacts = [];
        _filteredContacts = [];
        _permissionState = _ContactsPermissionState.granted;
      });
      return;
    }

    final status = await Permission.contacts.status;
    if (status.isGranted) {
      final contacts = await FlutterContacts.getContacts(
          withProperties: true, withPhoto: true);
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _permissionState = _ContactsPermissionState.granted;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() =>
          _permissionState = _ContactsPermissionState.permanentlyDenied);
    } else {
      setState(() => _permissionState = _ContactsPermissionState.denied);
    }
  }

  Future<void> _requestPermission() async {
    final result = await Permission.contacts.request();
    if (result.isGranted) {
      await _fetchContacts();
    } else if (result.isPermanentlyDenied) {
      setState(() =>
          _permissionState = _ContactsPermissionState.permanentlyDenied);
    } else {
      setState(() => _permissionState = _ContactsPermissionState.denied);
    }
  }

  void _onContactTapped(Contact contact) {
    if (contact.phones.isNotEmpty) {
      final number = contact.phones.first.number;
      _showContactOptions(contact, number);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This contact has no phone number.')),
      );
    }
  }

  void _showContactOptions(Contact contact, String number) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(contact.displayName,
                  style:
                      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.call),
                title: Text('Call $number'),
                onTap: () async {
                  Navigator.pop(context);
                  final error = await getIt<CallViewModel>()
                      .makeCall(number, voiceOnly: true);
                  if (!context.mounted || error == null) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy to Dialpad'),
                onTap: () {
                  Navigator.pop(context);
                  final dialpadViewModel =
                      Provider.of<DialpadViewModel>(context, listen: false);
                  dialpadViewModel.setDestination(number);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Number copied to Dialpad')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionEmptyState() {
    final isPermanentlyDenied =
        _permissionState == _ContactsPermissionState.permanentlyDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.contacts_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isPermanentlyDenied
                  ? 'Contacts access is disabled. Enable it in Settings to see your contacts here.'
                  : 'Allow access to your contacts to see them here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isPermanentlyDenied ? openAppSettings : _requestPermission,
              child: const Text('Grant Access'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    final contacts = _filteredContacts ?? const [];
    if (contacts.isEmpty) {
      return const Center(child: Text('No contacts found'));
    }

    final grouped = groupContactsByLetter(contacts);
    final letters = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: _fetchContacts,
      child: ListView.builder(
        itemCount: letters.length,
        itemBuilder: (context, letterIndex) {
          final letter = letters[letterIndex];
          final letterContacts = grouped[letter]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  letter,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              for (final contact in letterContacts)
                ListTile(
                  leading: (contact.photoOrThumbnail != null)
                      ? CircleAvatar(
                          backgroundImage:
                              MemoryImage(contact.photoOrThumbnail!))
                      : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(contact.displayName),
                  subtitle: contact.phones.isNotEmpty
                      ? Text(contact.phones.first.number)
                      : null,
                  onTap: () => _onContactTapped(contact),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import Contacts',
            onPressed: () {
              _fetchContacts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing contacts...')),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.transparent,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _permissionState == _ContactsPermissionState.denied ||
                    _permissionState ==
                        _ContactsPermissionState.permanentlyDenied
                ? _buildPermissionEmptyState()
                : _contacts == null
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContactsList(),
          ),
        ],
      ),
    );
  }
}
```

Note: `widget.darkTheme` is accepted but not yet acted on visually in this task — Task 9 branches the styling on it. This keeps this task's diff purely about permission/sorting/refresh logic, independently reviewable from Task 9's visual changes.

- [ ] **Step 2: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/features/contacts/presentation/views/contacts_view.dart`
Expected: `No issues found!`

- [ ] **Step 3: Run the Task 3 pure-function test to confirm the integration point still matches**

Run: `/home/user/snap/flutter/common/flutter/bin/flutter test test/features/contacts/data/utils/contact_grouping_test.dart`
Expected: all 3 tests still PASS (this task's `_buildContactsList` calls `groupContactsByLetter` with the exact signature Task 3 produced — no test changes needed here since the plugin/permission calls in this file aren't unit-testable without platform-channel mocking, consistent with this session's established precedent of not force-mocking platform integrations).

- [ ] **Step 4: Commit**

```bash
git add lib/features/contacts/presentation/views/contacts_view.dart
git commit -m "feat(contacts): add permission-state handling, alphabetical sections, and pull-to-refresh"
```

---

### Task 9: `ContactsView` dark visual restyle

**Files:**
- Modify: `lib/features/contacts/presentation/views/contacts_view.dart`

**Interfaces:**
- Consumes: `widget.darkTheme` (added in Task 5/8); `WunzaColors.dialerPanelFill`/`dialerKeypadFill` are **not** reused here directly — see Context below for why.

**Context:** When `darkTheme` is true (only ever passed by `DialpadView`, Task 5), this widget is already rendered inside `DialpadView`'s own `GlassPanelContainer`/`DialerGradientBackground` — wrapping it in a second nested gradient/panel would double up the visual. So the dark variant here does **not** call `DialerGradientBackground`/`GlassPanelContainer` itself; it drops its own `Scaffold`/`AppBar` entirely (mirroring `RecentsView`'s Task 4 treatment — no redundant "Contacts" title bar stacked under `DialpadView`'s own top bar) and renders transparent-background content with dark-appropriate colors, inheriting the parent's gradient. When `darkTheme` is false (the default, used by `CallingView`), the exact `Scaffold`+`AppBar`+light-search-field structure from Task 8 is preserved unchanged.

- [ ] **Step 1: Branch `build()` on `widget.darkTheme`, and add dark-styled helper methods**

In `lib/features/contacts/presentation/views/contacts_view.dart`, make these changes:

Replace the `_buildPermissionEmptyState` method with two variants — rename the existing one and add a dark counterpart:

```dart
  Widget _buildPermissionEmptyState() {
    return widget.darkTheme
        ? _buildPermissionEmptyStateDark()
        : _buildPermissionEmptyStateLight();
  }

  Widget _buildPermissionEmptyStateLight() {
    final isPermanentlyDenied =
        _permissionState == _ContactsPermissionState.permanentlyDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.contacts_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isPermanentlyDenied
                  ? 'Contacts access is disabled. Enable it in Settings to see your contacts here.'
                  : 'Allow access to your contacts to see them here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isPermanentlyDenied ? openAppSettings : _requestPermission,
              child: const Text('Grant Access'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionEmptyStateDark() {
    final isPermanentlyDenied =
        _permissionState == _ContactsPermissionState.permanentlyDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.contacts_outlined, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              isPermanentlyDenied
                  ? 'Contacts access is disabled. Enable it in Settings to see your contacts here.'
                  : 'Allow access to your contacts to see them here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isPermanentlyDenied ? openAppSettings : _requestPermission,
              child: const Text('Grant Access'),
            ),
          ],
        ),
      ),
    );
  }
```

Replace the `_buildContactsList` method's `ListTile`/section-header colors with a dark-aware version:

```dart
  Widget _buildContactsList() {
    final contacts = _filteredContacts ?? const [];
    if (contacts.isEmpty) {
      return Center(
        child: Text(
          'No contacts found',
          style: TextStyle(
              color: widget.darkTheme ? Colors.white54 : Colors.black54),
        ),
      );
    }

    final grouped = groupContactsByLetter(contacts);
    final letters = grouped.keys.toList();
    final headerColor = widget.darkTheme ? Colors.white54 : Colors.grey;
    final titleColor = widget.darkTheme ? Colors.white : Colors.black87;
    final subtitleColor = widget.darkTheme ? Colors.white54 : Colors.black54;

    return RefreshIndicator(
      onRefresh: _fetchContacts,
      child: ListView.builder(
        itemCount: letters.length,
        itemBuilder: (context, letterIndex) {
          final letter = letters[letterIndex];
          final letterContacts = grouped[letter]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  letter,
                  style: TextStyle(fontWeight: FontWeight.bold, color: headerColor),
                ),
              ),
              for (final contact in letterContacts)
                ListTile(
                  leading: (contact.photoOrThumbnail != null)
                      ? CircleAvatar(
                          backgroundImage:
                              MemoryImage(contact.photoOrThumbnail!))
                      : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(contact.displayName,
                      style: TextStyle(color: titleColor)),
                  subtitle: contact.phones.isNotEmpty
                      ? Text(contact.phones.first.number,
                          style: TextStyle(color: subtitleColor))
                      : null,
                  onTap: () => _onContactTapped(contact),
                ),
            ],
          );
        },
      ),
    );
  }
```

Replace the `build()` method to branch on `widget.darkTheme`:

```dart
  @override
  Widget build(BuildContext context) {
    if (widget.darkTheme) {
      return Column(
        children: [
          _buildSearchField(dark: true),
          Expanded(
            child: _permissionState == _ContactsPermissionState.denied ||
                    _permissionState ==
                        _ContactsPermissionState.permanentlyDenied
                ? _buildPermissionEmptyState()
                : _contacts == null
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white70))
                    : _buildContactsList(),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import Contacts',
            onPressed: () {
              _fetchContacts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing contacts...')),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildSearchField(dark: false),
          Expanded(
            child: _permissionState == _ContactsPermissionState.denied ||
                    _permissionState ==
                        _ContactsPermissionState.permanentlyDenied
                ? _buildPermissionEmptyState()
                : _contacts == null
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContactsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({required bool dark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.transparent,
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: dark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
          prefixIcon: Icon(Icons.search, color: dark ? Colors.white54 : null),
          filled: true,
          fillColor: dark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: dark ? Colors.white54 : null),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        ),
      ),
    );
  }
```

(This last change also removes the search field's construction from being inline in `build()` — it's now the shared `_buildSearchField` helper used by both branches, avoiding duplicating the `TextField` structure.)

- [ ] **Step 2: Verify it compiles**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze lib/features/contacts/presentation/views/contacts_view.dart`
Expected: `No issues found!`

- [ ] **Step 3: Verify the full repo analyzes cleanly (this is the final task touching every file in this plan)**

Run: `/home/user/snap/flutter/common/flutter/bin/dart analyze`
Expected: only the same pre-existing, unrelated issues present before this plan started (confirm by comparing against a baseline run before Task 1, if available) — zero new issues.

- [ ] **Step 4: Run the full set of this plan's focused tests**

Run:
```
/home/user/snap/flutter/common/flutter/bin/flutter test test/features/dialpad/presentation/widgets/ test/features/contacts/data/utils/contact_grouping_test.dart
```
Expected: all tests from Tasks 1, 2, and 3 PASS (Task 9 doesn't modify any of those files, so this is a regression check).

- [ ] **Step 5: Commit**

```bash
git add lib/features/contacts/presentation/views/contacts_view.dart
git commit -m "style(contacts): add dark glass visual variant for the dialer's embedded Contacts tab"
```

---

## Manual Verification (post-plan, device/emulator — environment-blocked in this sandbox)

- Open the dialer sheet from Home's dial button — dark gradient + glass panel + keypad render per the reference.
- Enter digits, confirm "Enter number" placeholder disappears and the number displays correctly; backspace works.
- Place a call — confirm it still works exactly as before (no change to `SipUtils.placeOutgoingCall`/`_handleCall`).
- Tap Recents — dark-styled list of real recent calls shows; tap Contacts — dark-styled real device contacts show, sorted with section headers.
- Deny contacts permission once, then permanently deny (via device settings) — confirm both empty states render with the correct message and that "Grant Access" does the right thing in each case (re-prompt vs. opening Settings).
- Pull-to-refresh on the contacts list re-syncs.
- Tap Market Place — sheet closes and `ShoppingView` opens.
- Reopen the sheet — confirms it always starts fresh at the keypad.
- Open `CallingView`'s own Contacts tab (a different screen) — confirm it still renders in its original light style, completely unaffected by any of the above.
