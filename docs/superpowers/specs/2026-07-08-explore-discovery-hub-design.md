# Explore Discovery Hub — Design Spec

Date: 2026-07-08
Status: Approved, pending implementation plan

## Context

The user asked for a "world-class Explore page" — a discovery hub with a sticky
search bar, quick categories, a banner carousel, and up to 15 content sections
(Trending, Events, Products, Businesses, Deals, Services, Nearby, New,
Suggested, Interests, Updates, Continue Exploring) — plus, in a follow-up
message, a full social layer (stories with 24h expiry, a post composer, and a
mixed-media feed with near-real-time engagement).

A codebase check found **no existing backend or data model for stories, posts,
or a feed anywhere in SuperApp** (a VoIP calling + shopping + payments app with
a gRPC-backed account/dashboard layer, nothing social-content-related). The
social layer is not a UI task — it needs data models, media upload, an expiry
job for stories, and a feed/real-time-update mechanism, none of which exist.
Building it alongside the discovery-hub UI would either produce a shallow,
non-functional version of it, or balloon this into a multi-project effort.

**Decision (user-confirmed):** decompose into separate projects. This spec
covers only the discovery-hub UI, built as a polished visual layer over static
placeholder data — the same pattern the prior `ExploreTab` placeholder
(Task 5 of the glass-bottom-nav plan) already used. The social layer (stories,
composer, feed) is explicitly out of scope, to be scoped as its own future
project once/if the platform builds the backing infrastructure.

This spec also **replaces** the placeholder `ExploreTab` shipped in the
glass-bottom-nav work — that version's `_Section`/`_MediaCard`/`_RowSection`
(Trending, Recommended, Nearby Offers, Recently Added, all `String`-only) is
superseded entirely by the richer, typed design below.

## Goals

- A search bar, quick categories, banner carousel, and 4 flagship content
  sections (Trending Now, Recommended Products, Popular Businesses, Deals &
  Promotions), all on static placeholder data, built to a genuinely premium
  visual bar (not flat text-only cards).
- A reusable section component so the remaining ~8 carousels from the user's
  original list can be added later with minimal new code — same component,
  different data.
- Visual consistency with the just-shipped nav: reuse its coral→pink /violet
  accent tokens, no new hues introduced.
- Mobile-only (matches the rest of the app).

## Non-goals

- The entire social layer: stories (with 24h expiry/seen-unseen state), post
  composer, mixed-media feed with live engagement counts. Separate future
  project — needs backend data models this app doesn't have yet.
- The remaining 8 carousels from the user's original 15-section list (Featured
  Events, Popular Services, Nearby Discoveries, New on the Platform, Suggested
  For You, Browse by Interests, Platform Updates, Continue Exploring) — added
  later using the `DiscoverySection` component this spec builds.
- Any real search backend, results screen, or query execution — the search
  sheet operates entirely on static local data (recent/trending searches are
  illustrative placeholders, suggestions are a local substring filter).
- Tablet/desktop responsive layouts.
- Loading skeletons and error states — content is static, so nothing is
  actually being fetched and nothing can fail. These become meaningful once a
  real data layer exists.
- Filtering the sections below by selected category/search — deferred, since
  it needs a shared queryable data layer this round deliberately doesn't build.

## File structure

Replaces `lib/features/home/presentation/widgets/explore_tab.dart` entirely
(deletes its current `_Section`/`_MediaCard`/`_RowSection` content). New files:

- `lib/features/home/presentation/widgets/explore_tab.dart` — top-level
  composition: pinned search bar, quick categories, banner carousel, the 4
  flagship `DiscoverySection`s, in that order.
- `lib/features/home/presentation/widgets/explore_models.dart` — plain data
  classes (`DiscoveryItem`, `ExploreCategory`) plus the static placeholder
  lists consumed by the page.
- `lib/features/home/presentation/widgets/explore_search_sheet.dart` — the
  full-screen search modal.
- `lib/features/home/presentation/widgets/discovery_section.dart` — the
  reusable `DiscoverySection` widget and its card.

## Data model

```dart
class DiscoveryItem {
  final String id;
  final String title;
  final String subtitle;   // price / rating / distance / free text
  final String? badge;     // e.g. "Sale", "New" — null if none
  final Color tintColor;   // drives the placeholder image-block gradient
}

class ExploreCategory {
  final String id;
  final String label;
  final IconData icon;
}
```

Static placeholder lists for categories and each of the 4 flagship sections'
items live in `explore_models.dart` as `const` lists. No repository, no
fetching, no async — matches the "static now, real data later" boundary
already established for the rest of Explore.

## Sticky search bar + search sheet

The search bar is a pinned header (`SliverPersistentHeader`) at the top of
`ExploreTab`'s scroll view, so it stays visible while the sections below
scroll. Shows a search icon, the placeholder text "Search products,
businesses, events, services, people...", and a filter icon button. The
filter button opens the existing `MaintenanceScreen` ("Coming soon") — same
placeholder pattern used elsewhere in the app (Send/Scan/Pay, Bills,
Providers) for capabilities that don't have a backend yet.

Tapping the bar opens `ExploreSearchSheet` as a full-screen route
(`Navigator.push` with `MaterialPageRoute(fullscreenDialog: true)`) rather
than a bottom sheet, since it needs an auto-focused text field, a back
button, and full scrollable content — the standard Flutter pattern for a
search takeover. Contents:

- Auto-focused text field with a back/close button.
- **Recent searches**: ~4 static placeholder strings, each removable (local
  `setState` only, not persisted).
- **Trending searches**: ~6 static rows/chips with a trending icon.
- **Category shortcuts**: reuses the same `ExploreCategory` chips as the main
  page.
- **Live suggestions**: as the user types, a case-insensitive substring filter
  over one combined static list of `DiscoveryItem` titles pulled from the 4
  flagship sections' placeholder data. Instant, no debounce (it's local).

Selecting a suggestion or submitting text closes the sheet and fills the
search bar's display text — no results screen, since there's no backend to
query.

## Quick categories + banner carousel

**Quick categories**: a horizontal row of `ChoiceChip`-style pills below the
search bar (placeholder set: Shopping, Services, Events, Nearby, Deals,
Community). Tapping toggles a visual "selected" state only — it does not
filter the sections below (explicit non-goal above).

**Banner carousel**: a new `_ExploreBannerCarousel`, visually modeled on the
existing `GlidePromotionsCarousel` (`PageController` with a `viewportFraction`,
dot page-indicator, gradient cards) but with its own placeholder banner set
relevant to platform-wide discovery (e.g. "Refer a friend," "New: Split
payments," "Explore local events") — not coupled to the `shopping.Banner`
model, since these banners aren't shopping-specific. Tapping a banner opens
the placeholder `MaintenanceScreen`.

Active category chip and active page-dot use the nav's `navIndicator`
(violet) or PAD gradient tokens as appropriate for visual continuity — no new
color tokens introduced.

## `DiscoverySection` component + card design

```dart
class DiscoverySection extends StatelessWidget {
  const DiscoverySection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onSeeAll,
  });
  final String title;
  final String subtitle;
  final List<DiscoveryItem> items;
  final VoidCallback onSeeAll;
}
```

Renders: header row (title, subtitle below it, "See all" `TextButton` on the
trailing edge — opens `MaintenanceScreen`, no listing screen exists yet),
followed by a horizontal `ListView.separated` of cards built from `items`.

**Card** (~160px wide, reused across all 4 sections):
- Rounded 20px surface-tinted container.
- Image-placeholder block using the item's `tintColor` as a subtle two-stop
  gradient (richer than Task 5's flat single-color block).
- Optional badge (`item.badge`), top corner, coral pill with white text — only
  rendered when non-null.
- Title (1 line, bold, ellipsis) + subtitle (1 line, muted, ellipsis) — used
  for price/rating/location text (e.g. "$12.99", "4.8 ★", "0.4 mi away").

**The 4 flagship sections**, each a `DiscoverySection` with its own
placeholder `items` list and copy:
1. **Trending Now** — "What's popular right now"
2. **Recommended Products** — "Picked for you"
3. **Popular Businesses** — "Storefronts people love"
4. **Deals & Promotions** — "Limited-time offers" (every item has a badge,
   e.g. "20% off")

This fully replaces Task 5's `Nearby Offers`/`Recently Added` sections — they
are dropped, not carried forward.

## Page composition

`ExploreTab` order, top to bottom: pinned search bar → quick categories →
banner carousel → Trending Now → Recommended Products → Popular Businesses →
Deals & Promotions, with ~140px bottom padding (matching the convention set in
the glass-bottom-nav work) to clear the floating `GlassBottomNav`.

## Accessibility

- Search bar and filter button: `Semantics`/`tooltip`.
- Category chips: `ChoiceChip`'s built-in semantics (no extra wrapper needed).
- Each `DiscoveryItem` card: `Semantics(button: true, label: '$title,
  $subtitle')`.
- Applies the lesson from the nav's final review (the PAD button's missing
  Semantics label) proactively rather than retroactively.

## Testing

- `discovery_section_test.dart`: renders title/subtitle/items; "See all" tap
  invokes the callback.
- `explore_banner_carousel_test.dart` (or folded into the main test file):
  renders; swiping updates the active page-dot.
- `explore_categories_test.dart` (or folded in): tapping a chip toggles its
  selected visual state.
- `explore_search_sheet_test.dart`: opens on tap; typing filters the
  suggestion list; removing a recent search removes it from the displayed
  list.
- `explore_tab_test.dart`: smoke test confirming the search bar, categories,
  banner, and all 4 flagship sections render (successor to Task 5's test,
  updated for the new section set).

## Open items deferred to later specs

- The remaining 8 carousels from the original 15-section list.
- The entire social layer (stories, composer, feed) — separate future
  project, needs its own backend-design spec first.
- Real search backend and results screen.
- Category/search filtering of the sections below.
- Tablet/desktop responsive layouts.
- Loading skeletons and error states, once real data-fetching exists.
