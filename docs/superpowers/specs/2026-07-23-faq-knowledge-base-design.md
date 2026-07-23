# FAQ Knowledge Base (Phase 2, Slice 1) — Design Spec

Date: 2026-07-23
Status: Approved, pending implementation plan

## Context

The user's long-term goal is a RAG-backed AI support assistant: a backend
that retrieves relevant company documents (via embeddings + vector search)
and grounds LLM-generated replies in them, with conversation memory and a
richer human-escalation handoff. That system decomposes into six largely
independent subsystems (knowledge base, RAG retrieval, LLM-backed answer
generation, conversation memory, escalation/ticketing, analytics) — too
large for one spec. This is the first slice: **the knowledge base**, the
foundation everything else depends on.

Today, "Dash" (the floating chat assistant shipped in the prior phase —
see `docs/superpowers/specs/2026-07-22-dash-chat-assistant-design.md`) and
Help & Support's FAQ browser both read a hardcoded Dart constant,
`faqData` (`lib/features/help_support/data/faq_data.dart`) — 7 categories,
~40 question/answer items, compiled into the app. Updating any FAQ content
today requires an app release.

The app already has a working backend for this kind of content: an
Express + Mongoose API (`backend/`) with existing CRUD models
(`Category`, `Banner`, `Voucher`, etc.) and a small vanilla-JS admin panel
(`admin-panel/`) that manages them via JWT-authenticated REST calls. This
slice extends that existing stack rather than building a parallel one —
no vector DB, no embeddings, no LLM calls yet (those are later slices).

## Goals

- FAQ content (category title, question/answer items) lives in MongoDB,
  manageable by admins through a new `admin-panel/faqs.html` page —
  content updates take effect without an app release.
- The Flutter app fetches this content over a public `GET /api/faqs`
  endpoint, replacing the static `faqData` constant as the single source
  of truth for both Dash's keyword-matching engine and Help & Support's
  FAQ browser/search.
- The app caches fetched content locally (`SharedPreferences`) and serves
  it instantly on next launch while refreshing in the background — no
  blank/loading FAQ experience on every open, and it keeps working
  through a slow or briefly-unavailable network.
- The existing ~40 FAQ items migrate losslessly via a one-time seed
  script — nothing is lost in the cutover.
- Content (question/answer) and presentation (icon, color) stay decoupled:
  the backend model is pure content; the Flutter app maps
  category-title → icon/color via a small static lookup table.

## Non-goals

- Embeddings, vector search, or any LLM-generated answers — this slice is
  CRUD + fetch + cache only. The keyword-matching logic already in
  `DashViewModel` is unchanged; only its data source moves.
- Conversation memory, human-escalation/ticketing changes, or analytics —
  each a separate future slice.
- An icon/color picker in the admin UI — admins manage question/answer
  content only; a newly-admin-created category not yet in the app's
  lookup table falls back to a generic icon/color until a future app
  update adds it explicitly.
- Search-on-the-backend (a `GET /api/faqs?q=...` endpoint) — the full
  dataset is cached on-device (same reasoning as today's client-side
  search), so search stays client-side.

## Architecture

**Backend** (`backend/`):
- `models/faq.model.js` — new Mongoose model:
  ```js
  {
    title: { type: String, required: true, unique: true, trim: true },
    items: [{
      question: { type: String, required: true },
      answer:   { type: String, required: true },
    }],
  }, { timestamps: true }
  ```
- Routes added to `index.js` alongside the existing inline route blocks
  (matching the `Category`/`Voucher` pattern exactly):
  - `GET /api/faqs` — public (no auth), returns all categories with items.
    Public because it's read-only content the app itself displays, same
    trust level as `GET /api/categories` today.
  - `POST /api/faqs`, `PUT /api/faqs/:id`, `DELETE /api/faqs/:id` —
    behind the existing `auth.middleware.js`, admin-only.
- `scripts/seed-faqs.js` — one-time script, run manually once against
  the production/dev database, that inserts the current 7
  categories/~40 items (copied as a JS literal from today's
  `faq_data.dart` content) via the `Faq` model. Not part of the app's
  runtime startup — a migration utility, run once.

**Admin panel** (`admin-panel/`):
- `faqs.html` + `faqs.js`, structurally mirroring `categories.html/js`:
  list all FAQ categories, expand to see/edit items, create/delete
  categories, add/edit/remove individual items within a category. Same
  `authFetch`/localStorage-token pattern as every other admin page.

**Flutter** (`lib/`):
- `lib/features/faq/data/faq_service.dart` — `http`-based fetch of
  `GET /api/faqs`, JSON-decoded into `FaqCategory`/`FaqItem` (same shape
  already defined in `lib/features/help_support/data/faq_data.dart`,
  which gains `fromJson`/`toJson`). Same conventions as
  `ShoppingService` (base URL constant, try/catch → `ok` flag, no thrown
  exceptions across the service boundary).
- `lib/features/faq/presentation/viewmodels/faq_viewmodel.dart` — new
  `ChangeNotifier`, registered as a `get_it` lazy singleton and exposed
  via `MultiProvider` in `main.dart` like every other view model:
  - `List<FaqCategory> get categories` — cached/last-known data, `[]`
    before first load.
  - `bool get loading`
  - `Future<void> loadCached()` — reads the last-cached JSON from
    `SharedPreferences` synchronously-ish on startup (before the network
    call resolves), so category screens have content immediately if the
    app has run before.
  - `Future<void> refresh()` — fetches from `FaqService`, updates
    `categories`, writes the new JSON to `SharedPreferences`, notifies
    listeners. Called once on app start after `loadCached()`, and
    available for manual pull-to-refresh.
- `lib/features/help_support/data/faq_data.dart` keeps its `FaqItem`/
  `FaqCategory` class definitions (now with `fromJson`/`toJson`) but the
  `const faqData = [...]` literal is deleted entirely.
- `DashViewModel` (`lib/features/dash/presentation/viewmodels/dash_viewmodel.dart`)
  gains a constructor dependency on `FaqViewModel` — same pattern as
  `DialpadViewModel` already taking `PaymentsClient` — and
  `_matchReply`'s FAQ-fallback loop reads `faqViewModel.categories`
  instead of the static import. DI registration in `inject.dart` updates
  to `DashViewModel(getIt<FaqViewModel>())`.
- Help & Support's `_MainScreenState` (search) and the FAQ-browsing
  screens (`_FaqCategoryScreen`, `_ServiceHelpScreen`) read
  `context.watch<FaqViewModel>().categories` instead of the static
  `faqData`.
- Category icon/color: a small
  `const Map<String, ({IconData icon, Color color})> faqCategoryStyles`
  keyed by category title, with a fallback style
  (`Icons.help_outline` / a neutral gray) for any title not in the map —
  so an admin-created category never crashes the UI, just looks generic
  until a future app update adds it explicitly.

## Data flow & error handling

- App start: `FaqViewModel.loadCached()` populates `categories` from
  `SharedPreferences` if present (instant, no network wait), then
  `refresh()` runs in the background. If the app has never run before
  and the network call also fails, `categories` stays `[]` — Dash's
  fallback-reply path and Help & Support's FAQ section both already
  handle an empty/loading dataset gracefully (Dash's generic fallback
  reply doesn't require FAQ data; Help & Support's FAQ section shows an
  empty state).
- `refresh()` failures (network error, non-200) are swallowed at the
  service boundary (`ok: false`), logged, and `categories` simply keeps
  whatever was already cached — no user-facing error surface for a
  background refresh failure.
- Admin CRUD writes (`POST`/`PUT`/`DELETE`) return standard validation
  errors (missing `title`, empty `question`/`answer`) the same way
  `Category`'s routes already do — no new error-handling pattern
  introduced.

## Testing

- Backend: Jest tests for the `Faq` model and the four routes (following
  `backend/tests/posts.*.test.js`'s pattern) — public read returns
  seeded data, writes require a valid JWT, validation rejects
  missing/empty fields, delete removes the category.
- Flutter: `FaqViewModel` tests with a fake `FaqService` — successful
  fetch populates `categories` and caches it; a cached-then-refresh
  sequence shows cached data immediately while a slow refresh is
  in-flight; a failed refresh leaves previously-cached data intact.
- `DashViewModel` tests updated to construct it with a fake/stub
  `FaqViewModel` instead of relying on the (now-deleted) static
  `faqData` import — existing keyword-matching test cases keep their
  same expected outputs, only the data source changes.
- Manual: seed script run against a dev database; confirm `GET
  /api/faqs` returns all 7 categories; confirm the admin panel can
  create/edit/delete a category and item; confirm Dash and Help &
  Support both reflect an admin-made edit after a background refresh.
