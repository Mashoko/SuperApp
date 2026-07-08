# Explore Discovery Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder `ExploreTab` (from the glass-bottom-nav work) with a real discovery hub — a pinned search bar with a full search sheet, quick category chips, a banner carousel, and 4 flagship content sections (Trending Now, Recommended Products, Popular Businesses, Deals & Promotions) built on a single reusable `DiscoverySection` component — all on static placeholder data.

**Architecture:** Four new/rewritten files behind `ExploreTab`'s unchanged public interface (`const ExploreTab({super.key})` — no other file needs to change, since `HomeView`'s `case 1: return const ExploreTab();` already calls it this way). `explore_models.dart` holds typed placeholder data; `discovery_section.dart` is the one reusable section+card widget used by all 4 flagship sections; `explore_search_sheet.dart` is a full-screen search route; `explore_tab.dart` composes all of it via a pinned `SliverPersistentHeader` + the rest of the page content.

**Tech Stack:** Flutter (Material 3), no new packages.

## Global Constraints

- No new pub packages.
- Mobile-only layout (no tablet/desktop responsive work).
- No skeleton loading states, no error states — content is static, nothing is fetched, nothing can fail.
- No real search backend — the search sheet operates entirely on static local data (substring filter over placeholder items).
- Category chips and search do not filter the sections below (no shared queryable data layer this round).
- Reuse the nav's existing color tokens (`WunzaColors.navIndicator`, `padGradientStart`, `padGradientEnd`) — no new color tokens.
- Every interactive element that doesn't have a real destination yet (filter button, "See all", banner tap) opens the existing `MaintenanceScreen` ("Coming soon") — same placeholder pattern already used throughout this app (Send/Scan/Pay, Bills, Providers).
- This fully replaces Task 5 of the glass-bottom-nav plan's `ExploreTab` content (`_Section`/`_MediaCard`/`_RowSection`, and the "Nearby Offers"/"Recently Added" sections) — none of it is carried forward.

---

### Task 1: `explore_models.dart` — data model and placeholder data

**Files:**
- Create: `lib/features/home/presentation/widgets/explore_models.dart`
- Test: `test/features/home/explore_models_test.dart`

**Interfaces:**
- Produces:
  - `class DiscoveryItem { const DiscoveryItem({required String id, required String title, required String subtitle, required Color tintColor, String? badge}); }` with matching public fields `id`, `title`, `subtitle`, `tintColor`, `badge`.
  - `class ExploreCategory { const ExploreCategory({required String id, required String label, required IconData icon}); }` with matching public fields `id`, `label`, `icon`.
  - `const List<ExploreCategory> exploreCategories`
  - `const List<DiscoveryItem> trendingItems`
  - `const List<DiscoveryItem> recommendedItems`
  - `const List<DiscoveryItem> businessItems`
  - `const List<DiscoveryItem> dealItems`
  - `List<DiscoveryItem> get allDiscoveryItems` (combines the 4 lists above, in that order)
  - `const List<String> recentSearches`
  - `const List<String> trendingSearches`
  - Consumed by Tasks 2, 3, and 4.

- [ ] **Step 1: Write the failing test**

Create `test/features/home/explore_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart';

void main() {
  test('exploreCategories has non-empty ids and labels', () {
    expect(exploreCategories, isNotEmpty);
    for (final c in exploreCategories) {
      expect(c.id, isNotEmpty);
      expect(c.label, isNotEmpty);
    }
  });

  test('all four flagship item lists are non-empty', () {
    expect(trendingItems, isNotEmpty);
    expect(recommendedItems, isNotEmpty);
    expect(businessItems, isNotEmpty);
    expect(dealItems, isNotEmpty);
  });

  test('every deal item has a badge', () {
    for (final item in dealItems) {
      expect(item.badge, isNotNull);
    }
  });

  test('allDiscoveryItems concatenates all four flagship lists in order', () {
    expect(
      allDiscoveryItems.length,
      trendingItems.length +
          recommendedItems.length +
          businessItems.length +
          dealItems.length,
    );
    expect(allDiscoveryItems.first.id, trendingItems.first.id);
    expect(allDiscoveryItems.last.id, dealItems.last.id);
  });

  test('recentSearches and trendingSearches are non-empty', () {
    expect(recentSearches, isNotEmpty);
    expect(trendingSearches, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/explore_models_test.dart`
Expected: FAIL — `package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart` does not exist.

- [ ] **Step 3: Create the data model and placeholder data**

Create `lib/features/home/presentation/widgets/explore_models.dart`:

```dart
import 'package:flutter/material.dart';

/// One card's worth of content in a [DiscoverySection]. Placeholder data
/// only — see the Explore discovery hub design spec's non-goals for why
/// there's no repository/fetching here yet.
@immutable
class DiscoveryItem {
  const DiscoveryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tintColor,
    this.badge,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color tintColor;
  final String? badge;
}

/// One quick-category chip shown below the search bar and in the search
/// sheet's "Browse by category" section.
@immutable
class ExploreCategory {
  const ExploreCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const List<ExploreCategory> exploreCategories = [
  ExploreCategory(
      id: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag_outlined),
  ExploreCategory(
      id: 'services',
      label: 'Services',
      icon: Icons.miscellaneous_services_outlined),
  ExploreCategory(id: 'events', label: 'Events', icon: Icons.event_outlined),
  ExploreCategory(id: 'nearby', label: 'Nearby', icon: Icons.place_outlined),
  ExploreCategory(
      id: 'deals', label: 'Deals', icon: Icons.local_offer_outlined),
  ExploreCategory(
      id: 'community', label: 'Community', icon: Icons.groups_outlined),
];

const List<DiscoveryItem> trendingItems = [
  DiscoveryItem(
    id: 't1',
    title: 'Wireless earbuds',
    subtitle: '4.6 ★ · 2.1k sold',
    tintColor: Color(0xFFFF7A45),
  ),
  DiscoveryItem(
    id: 't2',
    title: 'Desk lamp',
    subtitle: '4.8 ★ · 890 sold',
    tintColor: Color(0xFF9B8CFF),
  ),
  DiscoveryItem(
    id: 't3',
    title: 'Running shoes',
    subtitle: '4.5 ★ · 3.4k sold',
    tintColor: Color(0xFFFF4D6D),
  ),
];

const List<DiscoveryItem> recommendedItems = [
  DiscoveryItem(
    id: 'r1',
    title: 'Weekend picks',
    subtitle: 'Curated for you',
    tintColor: Color(0xFF9B8CFF),
  ),
  DiscoveryItem(
    id: 'r2',
    title: 'Based on your history',
    subtitle: 'More like this',
    tintColor: Color(0xFFFF7A45),
  ),
  DiscoveryItem(
    id: 'r3',
    title: 'Similar to your saves',
    subtitle: 'You might like',
    tintColor: Color(0xFFFF4D6D),
  ),
];

const List<DiscoveryItem> businessItems = [
  DiscoveryItem(
    id: 'b1',
    title: 'Corner Cafe',
    subtitle: '4.7 ★ · 0.3 mi away',
    tintColor: Color(0xFFFF7A45),
  ),
  DiscoveryItem(
    id: 'b2',
    title: 'Green Market',
    subtitle: '4.4 ★ · 0.8 mi away',
    tintColor: Color(0xFF9B8CFF),
  ),
  DiscoveryItem(
    id: 'b3',
    title: 'Blue Bottle Roasters',
    subtitle: '4.9 ★ · 1.1 mi away',
    tintColor: Color(0xFFFF4D6D),
  ),
];

const List<DiscoveryItem> dealItems = [
  DiscoveryItem(
    id: 'd1',
    title: 'Accessories bundle',
    subtitle: 'Was \$40',
    tintColor: Color(0xFFFF7A45),
    badge: '20% off',
  ),
  DiscoveryItem(
    id: 'd2',
    title: 'Data top-up pack',
    subtitle: 'Limited time',
    tintColor: Color(0xFF9B8CFF),
    badge: '2x data',
  ),
  DiscoveryItem(
    id: 'd3',
    title: 'Voice bundle',
    subtitle: 'This week only',
    tintColor: Color(0xFFFF4D6D),
    badge: '15% off',
  ),
];

List<DiscoveryItem> get allDiscoveryItems => [
      ...trendingItems,
      ...recommendedItems,
      ...businessItems,
      ...dealItems,
    ];

const List<String> recentSearches = [
  'Wireless earbuds',
  'Corner Cafe',
  'Voice bundles',
  'Local events',
];

const List<String> trendingSearches = [
  'Running shoes',
  'Data top-up',
  'Green Market',
  'Split payments',
  'Desk lamp',
  'Nearby events',
];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/explore_models_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/explore_models.dart test/features/home/explore_models_test.dart
git commit -m "feat(home): add Explore discovery hub data model and placeholder data"
```

---

### Task 2: `DiscoverySection` reusable component

**Files:**
- Create: `lib/features/home/presentation/widgets/discovery_section.dart`
- Test: `test/features/home/discovery_section_test.dart`

**Interfaces:**
- Consumes: `DiscoveryItem` (Task 1).
- Produces: `class DiscoverySection extends StatelessWidget` with constructor `DiscoverySection({Key? key, required String title, required String subtitle, required List<DiscoveryItem> items, required VoidCallback onSeeAll})`. Consumed by Task 4.

- [ ] **Step 1: Write the failing test**

Create `test/features/home/discovery_section_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/discovery_section_test.dart`
Expected: FAIL — `package:mvvm_sip_demo/features/home/presentation/widgets/discovery_section.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/features/home/presentation/widgets/discovery_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart';

/// A titled, horizontally-scrolling row of [DiscoveryItem] cards with a
/// "See all" action. The one reusable building block for every flagship
/// (and, later, non-flagship) discovery section on the Explore tab.
class DiscoverySection extends StatelessWidget {
  const DiscoverySection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final List<DiscoveryItem> items;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _DiscoveryCard(item: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({required this.item});
  final DiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title}, ${item.subtitle}',
      // Without this, the descendant Text widgets (title, subtitle) merge
      // their own text into this node's computed label, producing
      // "Item One, Sub one\nItem One\nSub one" instead of the clean label
      // set above — verified by dumping the actual SemanticsNode tree.
      // excludeSemantics hides the children's semantics so only the
      // explicit label above is announced.
      excludeSemantics: true,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.tintColor.withValues(alpha: 0.35),
                        item.tintColor.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
                if (item.badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: WunzaColors.padGradientStart,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
```

Note on the `190`/`160`/`96` sizing: card height budget is 24px padding (12 top + 12 bottom) + 96px image + 8px spacer + ~20px title line + 4px spacer + ~18px subtitle line ≈ 170px content, inside a 190px slot — a ~20px buffer. (A prior task in this app's history shipped a similar horizontal-card layout with too little buffer and hit a real `RenderFlex` overflow once text wrapped — keep this buffer, don't shrink `190` without re-checking actual rendered height.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/discovery_section_test.dart`
Expected: PASS (3 tests). If you see a `RenderFlex overflowed` error instead, the card's actual content height exceeded the `190` budget — increase the `SizedBox(height: ...)` in `DiscoverySection` (not the card's internal spacing) until the overflow is gone, then note the new number in this file's comment.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/discovery_section.dart test/features/home/discovery_section_test.dart
git commit -m "feat(home): add reusable DiscoverySection component"
```

---

### Task 3: `ExploreSearchSheet` full-screen search

**Files:**
- Create: `lib/features/home/presentation/widgets/explore_search_sheet.dart`
- Test: `test/features/home/explore_search_sheet_test.dart`

**Interfaces:**
- Consumes: `DiscoveryItem`, `allDiscoveryItems`, `recentSearches`, `trendingSearches`, `exploreCategories` (Task 1).
- Produces: `class ExploreSearchSheet extends StatefulWidget` with constructor `ExploreSearchSheet({Key? key})` — no required params. Consumed by Task 4.

- [ ] **Step 1: Write the failing tests**

Create `test/features/home/explore_search_sheet_test.dart`:

```dart
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/home/explore_search_sheet_test.dart`
Expected: FAIL — `package:mvvm_sip_demo/features/home/presentation/widgets/explore_search_sheet.dart` does not exist.

- [ ] **Step 3: Implement the search sheet**

Create `lib/features/home/presentation/widgets/explore_search_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart';

/// Full-screen search takeover opened from the Explore tab's sticky search
/// bar. Everything here runs against static placeholder data — see the
/// Explore discovery hub design spec's non-goals for why there's no real
/// search backend yet.
class ExploreSearchSheet extends StatefulWidget {
  const ExploreSearchSheet({super.key});

  @override
  State<ExploreSearchSheet> createState() => _ExploreSearchSheetState();
}

class _ExploreSearchSheetState extends State<ExploreSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final List<String> _recent = List.of(recentSearches);
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<DiscoveryItem> get _suggestions {
    if (_query.isEmpty) return const [];
    final q = _query.toLowerCase();
    return allDiscoveryItems
        .where((i) => i.title.toLowerCase().contains(q))
        .toList();
  }

  void _selectSuggestion(String title) {
    _controller.text = title;
    Navigator.pop(context);
  }

  void _removeRecent(String value) {
    setState(() => _recent.remove(value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: 'Search products, businesses, events, services, people...',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_query.isNotEmpty) ...[
            Text('Suggestions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            if (_suggestions.isEmpty)
              Text('No matches', style: Theme.of(context).textTheme.bodySmall)
            else
              for (final item in _suggestions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.search),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                  onTap: () => _selectSuggestion(item.title),
                ),
          ] else ...[
            if (_recent.isNotEmpty) ...[
              Text('Recent searches',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              for (final term in _recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(term),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeRecent(term),
                  ),
                  onTap: () => _selectSuggestion(term),
                ),
              const SizedBox(height: 18),
            ],
            Text('Trending searches',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in trendingSearches)
                  ActionChip(
                    avatar: const Icon(Icons.trending_up, size: 16),
                    label: Text(term),
                    onPressed: () => _selectSuggestion(term),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Browse by category',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in exploreCategories)
                  ActionChip(
                    avatar: Icon(category.icon, size: 16),
                    label: Text(category.label),
                    onPressed: () => _selectSuggestion(category.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/home/explore_search_sheet_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/explore_search_sheet.dart test/features/home/explore_search_sheet_test.dart
git commit -m "feat(home): add ExploreSearchSheet full-screen search"
```

---

### Task 4: Rewrite `ExploreTab` — pinned search bar, categories, banner, flagship sections

**Files:**
- Modify: `lib/features/home/presentation/widgets/explore_tab.dart` (full-file replacement)
- Modify: `test/features/home/explore_tab_test.dart` (full-file replacement)

**Interfaces:**
- Consumes: `DiscoverySection` (Task 2), `ExploreSearchSheet` (Task 3), `exploreCategories`/`trendingItems`/`recommendedItems`/`businessItems`/`dealItems` (Task 1), `WunzaColors.navIndicator`/`padGradientStart`/`padGradientEnd` (`lib/core/theme.dart`, already exists), `MaintenanceScreen` (`lib/shared/widgets/maintenance_screen.dart`, already exists).
- Produces: `class ExploreTab extends StatefulWidget` with constructor `ExploreTab({Key? key})` — **unchanged from the current placeholder**, so no other file (`home_view.dart`) needs any change.

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `test/features/home/explore_tab_test.dart` with:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/home/explore_tab_test.dart`
Expected: FAIL — old `ExploreTab` doesn't have a search bar, category labels like "Shopping"/"Services", section titles like "Trending Now", or a `PageView`/banner dots.

- [ ] **Step 3: Rewrite `ExploreTab`**

Replace the entire contents of `lib/features/home/presentation/widgets/explore_tab.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/discovery_section.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_search_sheet.dart';
import 'package:mvvm_sip_demo/shared/widgets/maintenance_screen.dart';

/// The Explore tab's discovery hub: a pinned search bar, quick category
/// chips, a banner carousel, and 4 flagship [DiscoverySection]s — all on
/// static placeholder data. See the Explore discovery hub design spec for
/// what's deferred (the remaining ~8 carousels, real search, filtering,
/// tablet/desktop layouts, loading/error states, the social layer).
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  String _selectedCategoryId = exploreCategories.first.id;

  void _openSearchSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ExploreSearchSheet(),
      ),
    );
  }

  void _openMaintenance(
      {required String label, required IconData icon, required Color color}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MaintenanceScreen(label: label, icon: icon, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickySearchBarDelegate(
            onTap: _openSearchSheet,
            onFilterTap: () => _openMaintenance(
              label: 'Search filters',
              icon: Icons.tune,
              color: WunzaColors.navIndicator,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _QuickCategoriesRow(
                  selectedId: _selectedCategoryId,
                  onSelected: (id) => setState(() => _selectedCategoryId = id),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ExploreBannerCarousel(
                    onBannerTap: () => _openMaintenance(
                      label: 'Featured',
                      icon: Icons.campaign_outlined,
                      color: WunzaColors.padGradientStart,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DiscoverySection(
                        title: 'Trending Now',
                        subtitle: "What's popular right now",
                        items: trendingItems,
                        onSeeAll: () => _openMaintenance(
                          label: 'Trending Now',
                          icon: Icons.local_fire_department_outlined,
                          color: WunzaColors.padGradientStart,
                        ),
                      ),
                      DiscoverySection(
                        title: 'Recommended Products',
                        subtitle: 'Picked for you',
                        items: recommendedItems,
                        onSeeAll: () => _openMaintenance(
                          label: 'Recommended Products',
                          icon: Icons.auto_awesome_outlined,
                          color: WunzaColors.navIndicator,
                        ),
                      ),
                      DiscoverySection(
                        title: 'Popular Businesses',
                        subtitle: 'Storefronts people love',
                        items: businessItems,
                        onSeeAll: () => _openMaintenance(
                          label: 'Popular Businesses',
                          icon: Icons.storefront_outlined,
                          color: WunzaColors.padGradientEnd,
                        ),
                      ),
                      DiscoverySection(
                        title: 'Deals & Promotions',
                        subtitle: 'Limited-time offers',
                        items: dealItems,
                        onSeeAll: () => _openMaintenance(
                          label: 'Deals & Promotions',
                          icon: Icons.local_offer_outlined,
                          color: WunzaColors.padGradientStart,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  _StickySearchBarDelegate({required this.onTap, required this.onFilterTap});

  final VoidCallback onTap;
  final VoidCallback onFilterTap;

  static const double _height = 64;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Semantics(
        button: true,
        label: 'Search',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).hintColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search products, businesses, events, services, people...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).hintColor),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Filter',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onFilterTap,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.tune,
                          color: Theme.of(context).hintColor, size: 20),
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

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) {
    return oldDelegate.onTap != onTap || oldDelegate.onFilterTap != onFilterTap;
  }
}

class _QuickCategoriesRow extends StatelessWidget {
  const _QuickCategoriesRow(
      {required this.selectedId, required this.onSelected});

  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: exploreCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = exploreCategories[i];
          final selected = category.id == selectedId;
          return ChoiceChip(
            avatar: Icon(category.icon, size: 16),
            label: Text(category.label),
            selected: selected,
            selectedColor: WunzaColors.navIndicator.withValues(alpha: 0.18),
            onSelected: (_) => onSelected(category.id),
          );
        },
      ),
    );
  }
}

class _ExploreBanner {
  const _ExploreBanner(
      {required this.title, required this.subtitle, required this.colors});
  final String title;
  final String subtitle;
  final List<Color> colors;
}

const List<_ExploreBanner> _banners = [
  _ExploreBanner(
    title: 'Refer a friend',
    subtitle: 'Give \$5, get \$5 when they join',
    colors: [WunzaColors.padGradientStart, WunzaColors.padGradientEnd],
  ),
  _ExploreBanner(
    title: 'New: Split payments',
    subtitle: 'Send money together with friends',
    colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
  ),
  _ExploreBanner(
    title: 'Explore local events',
    subtitle: 'Discover things happening near you',
    colors: [Color(0xFF283593), Color(0xFF5C6BC0)],
  ),
];

class _ExploreBannerCarousel extends StatefulWidget {
  const _ExploreBannerCarousel({required this.onBannerTap});
  final VoidCallback onBannerTap;

  @override
  State<_ExploreBannerCarousel> createState() =>
      _ExploreBannerCarouselState();
}

class _ExploreBannerCarouselState extends State<_ExploreBannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: widget.onBannerTap,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: banner.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: banner.colors.last.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          banner.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          banner.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              key: Key('banner-dot-$i'),
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? WunzaColors.navIndicator
                    : WunzaColors.navIndicator.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/home/explore_tab_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the full set of Explore-related tests together**

Run: `flutter test test/features/home/explore_models_test.dart test/features/home/discovery_section_test.dart test/features/home/explore_search_sheet_test.dart test/features/home/explore_tab_test.dart`
Expected: PASS (15 tests total: 5 + 3 + 3 + 4).

- [ ] **Step 6: Run analyze**

Run: `flutter analyze lib/features/home/presentation/widgets/explore_tab.dart lib/features/home/presentation/widgets/explore_models.dart lib/features/home/presentation/widgets/discovery_section.dart lib/features/home/presentation/widgets/explore_search_sheet.dart`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/presentation/widgets/explore_tab.dart test/features/home/explore_tab_test.dart
git commit -m "feat(home): rewrite ExploreTab with search bar, categories, banner, and flagship sections"
```

---

## Manual verification (no automated task — same rationale as the glass-bottom-nav plan's Task 7)

After all 4 tasks are done, run the app and check:
- Tapping the search bar opens the full-screen search sheet; typing filters suggestions; removing a recent search works; back button returns to Explore.
- Category chips visually select/deselect on tap (no filtering of sections below — expected, per non-goals).
- Banner carousel swipes smoothly; dots track the active page; tapping a banner opens "Coming soon".
- All 4 flagship sections render with images, titles, subtitles, and (Deals only) badges; "See all" opens "Coming soon".
- Scrolling down keeps the search bar pinned at the top.
- Toggle light/dark mode from Profile — confirm cards, chips, and the pinned search bar all look correct in both.
