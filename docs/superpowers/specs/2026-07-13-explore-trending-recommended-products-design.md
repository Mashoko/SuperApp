# Explore: Real Trending + Recommended Products — Design Spec

Date: 2026-07-13
Status: Approved, pending implementation plan

## Context

The Explore tab's "Trending Now" and "Recommended Products" sections currently
render `DiscoveryItem`s — gradient-tinted placeholder boxes with hardcoded
titles like "Wireless earbuds" and "Weekend picks" (`lib/features/home/presentation/widgets/explore_models.dart`).
This is the first of several planned slices replacing the Explore tab's
placeholder content with real backend data (the user's full request also
covers Businesses, Events, Services, Nearby, Search, and Promotions — each is
a separate, independent sub-project to be sequenced later; this spec covers
Products only).

The app already has a working shopping stack: a `Product` Mongoose model and
`GET/POST/PUT/DELETE /api/products` routes on the backend, and a `Product`
Flutter model, `ShoppingService`, and `ShoppingViewModel` already used
elsewhere (the Shopping tab's product grid, cart, wishlist count). This spec
extends that existing stack rather than building a parallel one.

Two things this app does not have, discovered while scoping this spec:
- **No review system.** No `Review` model, no rating field anywhere.
- **No real wishlist wiring on the frontend**, despite the backend already
  supporting it (`/api/wishlist`, `/api/wishlist/add`,
  `/api/wishlist/remove/:productId`). `WishlistView` currently uses hardcoded
  "Mock wishlist items" and a no-op delete; `ShoppingViewModel` only has a
  wishlist *count* fetch, no add/remove/list state.
- **No sales/view analytics.** "Trending" cannot be computed from real usage
  data because none is tracked.

This spec makes deliberate, explicit scope decisions for each of these
(below), rather than silently faking behavior these gaps would otherwise
require.

## Goals

- Replace the Explore tab's "Trending Now" and "Recommended Products"
  sections with real `Product` data from the backend — no hardcoded arrays,
  no gradient placeholder boxes standing in for products.
- Each section fetches, loads, and fails independently (a Trending fetch
  failure must never block Recommended from rendering, and vice versa).
- Each section has a real loading (shimmer), success, empty, and error state
  — no blank space, ever.
- Product cards show real rating, verified-seller badge, delivery-available
  indicator, and discount badge — all backed by real schema fields, not
  fabricated numbers.
- The favourite (wishlist) button on product cards actually persists,
  reusing the backend's existing (currently unwired) wishlist endpoints.

## Non-goals

- Businesses, Events, Services, Nearby places, global Search, and
  Promotions sections — each a separate future spec.
- A real customer-facing review-writing flow. Rating/review-count are
  stored fields (admin/seed-settable), not derived from actual submitted
  reviews yet.
- Real usage-analytics-driven trending (view counts, purchase velocity).
  "Trending" is an admin-settable flag for this slice.
- ML-based / collaborative-filtering recommendations. "Recommended" is
  simple category-affinity rules (below).
- Fixing the rest of `WishlistView`'s mock data — this spec only wires the
  add/remove/toggle plumbing the Explore favourite button needs; the
  Wishlist tab's own display bugs are out of scope.
- Linking `Product` to the `Shop` model. Store name / verified / delivery
  are added directly to `Product` (see Data model) — a real Shop linkage is
  scoped to the future Businesses spec.

## Data model

### Backend: `backend/models/product.model.js`

Add six fields to the existing schema:

```js
averageRating: { type: Number, default: 0, min: 0, max: 5 },
reviewCount: { type: Number, default: 0 },
isTrending: { type: Boolean, default: false },
storeName: { type: String, required: false },
verifiedSeller: { type: Boolean, default: false },
deliveryAvailable: { type: Boolean, default: false },
```

`discountPrice` already exists on this schema — no backend change needed
for the discount badge, only a Flutter-side mapping (below).

### Flutter: `lib/models/shopping/product.dart`

Add matching fields, all defaulted so existing call sites (cart, wishlist
tile, shopping grid) keep compiling unchanged:

```dart
final double? discountPrice;
final double averageRating;
final int reviewCount;
final bool isTrending;
final String? storeName;
final bool verifiedSeller;
final bool deliveryAvailable;
```

`Product.fromJson` reads these with safe defaults (`0`, `false`, `null`)
when absent, so products seeded before this migration don't crash parsing.

## Backend endpoint

Extend the existing `GET /api/products` route
(`backend/index.js:177-209`) with two new optional query params, rather
than adding `GET /products/trending` / `GET /products/recommended` as
separate routes — this reuses the existing pagination/category/search
filter-building logic instead of duplicating it three times, matching this
backend's existing minimal-route-proliferation convention (`shops`,
`banners`, etc. are all single flat routes with query-param variations).

- `?sort=trending` — filters to `isTrending: true`, sorts by
  `averageRating` descending (ties broken by `createdAt` descending).
- `?sort=recommended&userId=<id>` — computes category affinity from the
  requesting user's wishlist (a `Wishlist.find({ userId })` lookup,
  reusing the existing `Wishlist` model): if the user has wishlist items,
  filter to products in those categories, excluding products already in
  the user's wishlist or cart, sorted by `averageRating` descending. If the
  user has no wishlist items (new user) or no `userId` is supplied, falls
  back to all non-deleted products sorted by `createdAt` descending, then
  `averageRating` descending (i.e. "newest + highest-rated" as a stand-in
  for "popular," per the request's own explicit guidance for new users).
- Existing behavior (no `sort` param) is completely unchanged — this is
  purely additive.

Both variants reuse the existing `page`/`limit`/`totalPages` pagination
shape already returned by this route.

## Flutter data layer

### `lib/services/shopping_service.dart`

Two new methods, mirroring the existing `fetchProducts`'s signature and
error-handling style (silent-fallback on failure — an empty page is
recoverable via section-level retry UI, matching this app's established
`fetchFeed` convention from the Posts feature):

```dart
Future<({List<Product> products, int totalPages, int currentPage})>
    fetchTrendingProducts({required int page, int limit = 10});

Future<({List<Product> products, int totalPages, int currentPage})>
    fetchRecommendedProducts(
        {required String userId, required int page, int limit = 10});
```

Also new, to support the favourite button (currently entirely unwired on
the frontend despite the backend already supporting it):

```dart
Future<List<Product>> fetchWishlist(String userId); // GET /api/wishlist
Future<void> addToWishlist(String userId, String productId);
Future<void> removeFromWishlist(String userId, String productId);
```

### `lib/features/home/presentation/viewmodels/... ` — extending `ShoppingViewModel`

New, independent state per section (mirrors the Posts feature's
established per-section loading/error/hasMore pattern):

```dart
List<Product> get trendingProducts;
bool get trendingLoading;
String? get trendingError;

List<Product> get recommendedProducts;
bool get recommendedLoading;
String? get recommendedError;

Future<void> loadTrendingProducts();
Future<void> loadRecommendedProducts(String userId);
```

Each method sets only its own section's loading/error state and never
touches the other's — a Trending failure renders `FeedErrorState`-style UI
in the Trending row while Recommended keeps rendering normally (and vice
versa), directly satisfying "each section fetches independently."

New wishlist state, wired to the new service methods:

```dart
List<String> get wishlistProductIds; // just IDs, for fast "is this favourited" checks
Future<void> loadWishlist(String userId);
Future<void> toggleWishlist(String userId, String productId); // optimistic, matching Posts' toggleLike pattern
bool isWishlisted(String productId);
```

`toggleWishlist` follows the same optimistic-update-then-revert-on-failure
shape already established and tested for `PostsViewModel.toggleLike` in
this codebase: flip the local `wishlistProductIds` membership immediately,
call the service, revert on failure.

## UI

### Card: extend `lib/features/shopping/presentation/views/widgets/product_card.dart`

`ProductCard` already renders image, name, price, and a favourite button
(currently a no-op `onFavorite` callback wired to nothing). Extend it —
don't replace it — with:

- A rating row (star icon + `averageRating.toStringAsFixed(1)` + `(reviewCount)`),
  shown only when `reviewCount > 0` (a product with zero reviews shows no
  rating row at all, rather than a misleading "0.0 ★").
- A verified-seller badge (small checkmark chip) shown when `verifiedSeller`.
- A delivery-available indicator (small truck icon + "Delivery") shown when
  `deliveryAvailable`.
- A discount badge (e.g. "-20%", computed from `discountPrice` vs `price`)
  shown when `discountPrice != null && discountPrice! < price`; price row
  shows the discounted price with the original struck through.
- `storeName`, shown as a small secondary line under the product name when
  present.

All additions are optional/conditional on the field being present, so the
card degrades gracefully for products without these fields set, and the
existing Shopping-tab grid usage of `ProductCard` is unaffected (it simply
won't show these rows until its products carry the new fields).

The favourite button's `onFavorite` callback gets actually wired at the
call site (Explore's product rows) to `viewModel.toggleWishlist(userId,
product.productId)`, with the icon reflecting `viewModel.isWishlisted(...)`.

### Explore tab: `lib/features/home/presentation/widgets/explore_tab.dart` / `discovery_section.dart`

The "Trending Now" and "Recommended Products" `DiscoverySection` instances
(currently fed `trendingItems`/`recommendedItems` from
`explore_models.dart`) are replaced with a new section widget that renders
real `ProductCard`s in the same horizontally-scrolling row layout, backed
by `ShoppingViewModel.trendingProducts`/`recommendedProducts`. The other two
existing `DiscoverySection`s (Popular Businesses, Deals & Promotions) are
untouched — they remain on placeholder data until their own future specs.

### Loading state: shimmer

Reuse the existing `lib/shared/widgets/shimmer_widget.dart` (`ShimmerWidget`,
already built and already used on the home view) shaped like the real
`ProductCard` — image-area rectangle, two text-line rectangles, no new
shimmer package dependency needed.

### Empty state

Per the request's own example copy, shown when a section's fetch succeeds
with zero products:

```
No Trending Products Yet
Check back later. New products are added every day.
[Browse Categories]
```

(same structure for Recommended, with copy adjusted). "Browse Categories"
navigates to the existing category browse/search entry point already used
elsewhere in Explore.

### Error state

Matches the `FeedErrorState` pattern already established for Posts: a
centered message + "Try again" button that retries only that section's
load call — never a blank space, never silently falling back to fake data.

## Testing

- Backend: Jest/Supertest tests for the extended `/api/products` route —
  `sort=trending` returns only `isTrending: true` products in rating order;
  `sort=recommended&userId=` returns category-affinity results for a user
  with wishlist items, and falls back to newest+highest-rated for a user
  with none; existing (no `sort`) behavior is unchanged (regression test).
- Flutter service: `ShoppingService.fetchTrendingProducts` /
  `fetchRecommendedProducts` / wishlist methods, via `MockClient` — no live
  network calls.
- Flutter viewmodel: `ShoppingViewModel`'s new per-section state — loading/
  success/empty/error for both sections independently (one section's
  failure doesn't affect the other), plus `toggleWishlist`'s optimistic
  update and revert-on-failure (mirroring the existing `toggleLike` test
  pattern).
- Widget: the extended `ProductCard` renders the new rows correctly when
  present and omits them cleanly when absent (e.g. no rating row when
  `reviewCount == 0`); the new Explore product section renders shimmer
  while loading, real cards on success, the empty-state copy on an empty
  success, and `FeedErrorState`-style UI with a working retry on failure.

## Open items deferred to later specs

- Businesses, Events, Services, Nearby places, global Search, Promotions
  sections on Explore.
- A real review-writing flow (replacing the admin/seed-settable rating).
- Real usage-analytics-driven trending.
- ML/collaborative-filtering recommendations.
- The rest of `WishlistView`'s mock data (list display, count).
- Linking `Product` to `Shop`.
