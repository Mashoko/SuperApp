# Glass Bottom Nav — Design Spec

Date: 2026-07-07
Status: Approved, pending implementation plan

## Context

SuperApp (Flutter, `mvvm_sip_demo`) currently ships a plain `BottomAppBar` + centered
`FloatingActionButton` (`HangingDialerButton`) for its 4-tab shell (`HomeView`). The
user wants the app to "feel alive" and move away from its current dull/flat colors,
starting with the bottom navigation.

A visual prototype (`GlassNav.jsx`, a React/HTML artifact) was built earlier to
explore the direction: a floating glassmorphic pill nav with an embedded gradient
"PAD" button that fans open a radial quick-actions menu, a sliding violet active-tab
indicator, spring-eased motion, and scroll-aware show/hide.

This spec covers **porting that visual language into real Flutter widgets**, wired
into the actual app shell. It does **not** cover the app-wide color/theme overhaul
implied by "change all the dull colors" — that is phase 2, scoped separately, and
is explicitly out of bounds here so this stays a single reviewable unit of work.

## Goals

- Replace the current `BottomAppBar` + docked FAB with a floating glass pill nav
  matching the mockup's visual language (blur, gradient PAD, violet indicator,
  spring motion, scroll-aware hide).
- Preserve all existing navigable functionality currently reachable via the
  `Services` tab and the dialer FAB — nothing regresses.
- Introduce only nav-scoped color tokens; leave the rest of the app's theme
  (buttons, cards, other screens) untouched until phase 2.

## Non-goals

- App-wide `ColorScheme`/`ThemeData` overhaul (phase 2).
- Redesigning individual screens (Shop, Profile, Explore content beyond
  placeholder stubs, etc.) beyond what's needed to host the new nav.
- Wiring Send/Scan/Pay to real features — they don't exist yet, so they open the
  existing `MaintenanceScreen` ("Coming soon"), same pattern already used for
  Bills/Providers.

## Color tokens

Add to `lib/core/theme.dart` under `WunzaColors`, additive only (existing
`glidePrimary`/`glideAccent`/etc. are untouched and continue to drive the rest of
the app's theme until phase 2):

```dart
// Nav-only tokens (glass bottom nav), phase 2 will fold these into the
// app-wide ColorScheme.
static const Color navBgDark = Color(0xFF0B0B0E);
static const Color navBgLight = Color(0xFFF2F1EE);
static const Color navGlassDark = Color(0x801E1E24);   // rgba(30,30,36,0.5)
static const Color navGlassLight = Color(0x8CFFFFFF);  // rgba(255,255,255,0.55)
static const Color navIndicator = Color(0xFF9B8CFF);   // violet, active-tab glow only
static const Color padGradientStart = Color(0xFFFF7A45); // coral
static const Color padGradientEnd = Color(0xFFFF4D6D);    // pink
```

Exact glass border/shadow/highlight values are implementation detail, derived
from the `GlassNav.jsx` token block (`--gn-glass-border`, `--gn-shadow-float`,
`--gn-inner-shadow`) and adapted to Flutter's `BoxDecoration`/`BackdropFilter`.

## Structural change

**Today:**
- `Scaffold.bottomNavigationBar`: `BottomAppBar` (opaque, screen-edge to screen-edge).
- `Scaffold.floatingActionButton`: `HangingDialerButton`, `centerDocked`.

**New:**
- Both removed from `Scaffold`.
- New widget `GlassBottomNav` (new file,
  `lib/features/home/presentation/widgets/glass_bottom_nav.dart`) is placed as a
  `Positioned` widget (bottom-anchored, horizontally centered, inset from edges —
  a floating pill, not docked) inside the existing body `Stack` in `HomeView`.
- Floating (not docked) is required for the scroll-aware hide/show behavior — a
  `Scaffold.bottomNavigationBar` doesn't support sliding off past the screen edge
  the way a freely positioned widget does.
- Tab content already carries ~120-140px bottom padding (see `_GlideHomeTab`,
  `ServicesHubTab`), which is enough clearance for the floating pill; no content
  padding changes needed beyond what Explore's new content requires.

## Tabs

| Index | Tab | Icon | Notes |
|---|---|---|---|
| 0 | Home | `Icons.home_outlined` / `Icons.home` | Unchanged, plus relocated Services grid (see below) |
| 1 | Explore | `Icons.explore_outlined` / `Icons.explore` | New tab, replaces Services in the bar |
| 2 | Shop | `Icons.storefront_outlined` / `Icons.storefront` | Unchanged |
| 3 | Profile | `Icons.person_outline` / `Icons.person` | Unchanged |

### Services relocation

`ServicesHubTab`'s grid (`Calling`, `Utility Bills`, `Payments`, `Providers`,
`Call History`, `Order History`) is no longer a standalone tab. Its content is
folded into the **Home** tab (`_GlideHomeTab`), appended as a new section below
the existing `_QuickServicesRow` (which already duplicates a subset of these
items — `Call`, `Shop`, `Bills`, `Pay`, `History`, `Account`). The full grid
gives users access to everything `_QuickServicesRow`'s "See all" used to link to,
without a dedicated tab. `ServicesHubTab` becomes a section widget embedded in
Home rather than a full-screen tab (no route/navigation change needed since it
was reached via local tab-index state, not `Navigator`).

### Explore tab (new)

Ports the `ExplorePage` structure from `GlassNav.jsx`: category filter chips,
"Trending now", "Recommended for you", "Nearby offers", "Recently added"
sections. Since there's no backing data source for any of this yet, all content
is static placeholder data (mirroring the mockup's hardcoded arrays) — this is a
visual/structural port, not a new feature with real data wiring. A follow-up spec
can wire real data sources later.

## Center button (PAD)

- Visual: 64px circle, coral→pink gradient (`padGradientStart` → `padGradientEnd`),
  embedded into the pill's top edge, centered between Explore and Shop (same
  placement logic as the mockup — never overlapping a tab hit-target).
- **Short tap**: unchanged — opens the dialpad bottom sheet
  (`_openDialpadSheet`/`DialpadView`), exactly as `HangingDialerButton` does today.
- **Long-press**: fans open 3 quick-action buttons (Send, Scan, Pay) in a radial
  arc above the PAD, matching the mockup's fan animation (spring-eased
  scale/translate, staggered by index).
  - Each of Send/Scan/Pay opens the existing `MaintenanceScreen` ("Coming soon"),
    the same placeholder pattern already used for Bills/Providers in
    `_QuickServicesRow` today. No new backend/route wiring.
  - A scrim (blurred, semi-transparent) appears behind the fan while open;
    tapping the scrim or an action closes the fan.
  - Releasing the long-press does not auto-close the fan (mirrors the mockup:
    it's a toggled menu, not a press-and-hold radial picker) — closing happens
    via scrim tap or action tap.

## Motion

- **Active-tab indicator**: thin violet (`navIndicator`) pill sliding
  horizontally beneath the active tab, spring easing (`Curves.elasticOut` or
  equivalent spring curve), with a soft glow (`BoxShadow`).
- **Icon transition**: active icon scales up (~1.14x) with a slight upward
  translate, switches from outline to filled variant, and its label fades/grows
  in; inactive icons are outline-only, muted opacity. Spring-eased.
- **Ripple**: use Flutter's native `InkWell`/`Material` splash instead of the
  mockup's manual JS ripple hack — same tactile feedback, idiomatic Flutter,
  less code.
- **Scroll-aware show/hide**: wrap the tab content area (inside `HomeView`'s
  `AnimatedSwitcher`) in a `NotificationListener<UserScrollNotification>`. On
  scroll-down past a small threshold, hide the nav (`AnimatedSlide`/`AnimatedContainer`
  translating it off-screen); on scroll-up or near-top, show it. This works
  uniformly across all 4 tabs' independent scrollables without per-tab
  `ScrollController` plumbing, since scroll notifications bubble up the widget
  tree regardless of which descendant scrollable produced them.
- **Reduced motion**: durations collapse when `MediaQuery.of(context).disableAnimations`
  is true (Flutter's equivalent of `prefers-reduced-motion`).

## Theming / light-dark

No new infrastructure required. `ThemeProvider` (`lib/shared/theme/theme_provider.dart`)
already persists `ThemeMode` and is wired into `MaterialApp` in `main.dart`. The
new nav tokens above have both a dark and light value; `GlassBottomNav` reads the
active brightness via `Theme.of(context).brightness` the same way other widgets
in the app do, and selects the matching token pair.

## Accessibility

- All tap targets remain ≥48px (matches existing `_navItem` sizing conventions).
- `Semantics`/`tooltip` equivalents for each tab and the PAD (mirrors the
  mockup's `aria-label`/`aria-current`/`aria-expanded` usage).
- Visible focus treatment where applicable (Flutter's default focus highlight is
  sufficient; no custom focus ring needed unless testing shows otherwise).

## Testing

- Widget tests for `GlassBottomNav`: tab switch updates `_currentIndex` and
  indicator position; short tap on PAD opens dialpad sheet; long-press opens
  fan with 3 actions; tapping scrim/action closes fan.
- Manual verification (per this project's `/verify` conventions): run the app,
  exercise tab switching, PAD tap vs. long-press, scroll-hide on Home and
  Explore, and light/dark theme toggle from Profile.

## Open items deferred to later specs

- Phase 2: app-wide `ColorScheme`/`ThemeData` overhaul beyond the nav.
- Real data wiring for the Explore tab's sections.
- Real destinations for Send/Scan/Pay once those features exist.
