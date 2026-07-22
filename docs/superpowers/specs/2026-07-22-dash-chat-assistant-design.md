# Dash: Floating Chat Assistant (Phase 1 — UI + Static Answers) — Design Spec

Date: 2026-07-22
Status: Approved, pending implementation plan

## Context

The app currently has a full-screen "AI Assistant" chat (`_AIChatScreen`,
branded "Powered by FirstStreet AI") buried inside Help & Support
(`lib/features/help_support/presentation/views/help_support_view.dart:646-786`),
only reachable via a tile on the Help & Support main screen. It already does
simple keyword matching over a static FAQ dataset
(`_faqData`, `help_support_view.dart:97-131` — Wallet, Utility Bills,
Account & Security, General) and has its own "thinking" delay + chat bubble
UI.

This spec introduces **Dash**, a floating chat bubble reachable from every
main tab (Home, Explore, Shop, Profile), opening a bottom sheet instead of a
full-screen takeover. Dash replaces the old AI Assistant screen rather than
duplicating it: the FAQ dataset and keyword-matching logic move over, and the
old screen is deleted. Help & Support's "AI Chat" tile becomes another entry
point into the same Dash sheet.

This is phase 1 of a two-phase project (explicitly scoped down during
brainstorming):
- **Phase 1 (this spec):** the chat widget UI — bubble, bottom sheet, FAQ
  chips, message list, disclaimer — wired to static/canned responses via
  keyword matching. No live data, no LLM backend.
- **Phase 2 (future, separate spec):** real answering logic — live
  balance/bundle lookups against `AccountSummaryViewModel` /
  `PaymentsClient`, and/or an LLM-backed backend.

## Goals

- A `DashBubble` visible on every main tab (Home, Explore, Shop, Profile),
  positioned bottom-right, offset above the bottom nav so it never overlaps
  the dialer's call button.
- A small orange nudge dot on the bubble, shown once per app session until
  the sheet is first opened.
- Tapping the bubble opens `DashSheet` as a modal bottom sheet (dimmed home
  screen visible underneath, not a full-screen route).
- `DashSheet` contains: header (avatar, "Dash", static "Online · usually
  replies instantly" status, close button), scrolling message list with an
  empty-state greeting, a row of FAQ chips ("Check data balance", "How do I
  top up?", "Bundle prices", "Talk to a human"), a text input with send
  button, and a static disclaimer line under the input ("Dash is an AI
  assistant and can make mistakes").
- Tapping a chip sends it as a user message and returns a canned reply via
  keyword matching after a short artificial "thinking" delay, matching the
  existing `_AIChatScreen` pattern.
- Typing free text runs the same keyword-matching engine: first against the
  four quick topics, falling back to the migrated `_faqData` set, falling
  back to a generic "ask a chip or talk to a human" message.
- "Talk to a human" (chip tap or keyword match) calls the existing WhatsApp
  deep-link helper directly instead of returning a text reply.
- Help & Support's "AI Chat" tile opens the same Dash sheet instead of the
  old full-screen `_AIChatScreen`.
- The old `_AIChatScreen` class, its `_Screen.aiChat` full-screen route, and
  its duplicate FAQ-matching logic are deleted — one assistant
  implementation, multiple entry points.

## Non-goals (deferred to phase 2)

- Real live balance, bundle, or billing data in any reply — all responses
  are static/instructional text (e.g. redirecting to the wallet card's Data
  chip), not computed from `AccountSummaryViewModel` or `PaymentsClient`.
- Any LLM or external AI backend — matching is local keyword search only.
- Persisting chat history across app restarts — session-scoped only
  (in-memory, cleared on app restart).
- Any "unread count" or push-notification-driven nudge — the dot is a
  simple one-time-per-session flag, not backed by a server signal.

## Architecture & placement

`DashBubble` and the trigger for `DashSheet` are added directly into the
outer `Stack` in `lib/features/home/presentation/views/home_view.dart`
(alongside the existing `Positioned` `GlassBottomNav`, lines 182-201) — this
Stack wraps `_buildCurrentTab()`, so placing Dash here makes it visible
across all four tabs without touching each tab's own widget tree.

A new `DashViewModel` (`ChangeNotifier`, registered as a `get_it`
`registerLazySingleton` alongside the app's other view models in
`lib/core/di/inject.dart`) owns:
- Sheet-related session state (has the nudge dot been dismissed this
  session).
- The message list (`List<(bool isUser, String text)>`, mirroring
  `_AIChatScreen`'s existing shape).
- The canned-answer engine: the four quick-topic replies plus the migrated
  `_faqData` keyword search, both moved from `help_support_view.dart` into
  `DashViewModel` (or a small companion data file it owns).
- A method to trigger the WhatsApp escalation, reusing the existing
  `_openWhatsApp`-style helper/pattern already in `help_support_view.dart`.

Help & Support's "AI Chat" tile (`help_support_view.dart:250`,
`onAiChat: () => _push(_Screen.aiChat)`) is rewired to call
`getIt<DashViewModel>()`'s open method instead of pushing `_Screen.aiChat`.
The `_Screen.aiChat` enum value, its switch case, and the `_AIChatScreen`
class are deleted.

## Components

**`DashBubble`**
- Circular `Positioned` button, bottom-right, offset above
  `GlassBottomNav` so it and the dialer's call button both stay reachable.
- `WunzaColors.glidePrimary` (deep purple, `0xFF4A148C`) background with a
  chat-bubble icon.
- Small `WunzaColors.glideAccent` (vibrant orange, `0xFFFF6D00` — same color
  as the Top Up button) dot overlay, shown until `DashSheet` is opened for
  the first time in the session.

**`DashSheet`**
- Opened via `showModalBottomSheet` (dimmed barrier, current tab visible
  underneath).
- Header: avatar/icon, "Dash", static "Online · usually replies instantly"
  subtitle, close (X) button.
- Body: message list (`ListView.builder`, auto-scrolls to bottom on new
  message), empty state shows a short greeting ("Hi! I'm Dash 👋 I can help
  with balances, bundles, billing questions and more. What do you need?").
- FAQ chip row (wraps if needed): "Check data balance", "How do I top up?",
  "Bundle prices", "Talk to a human".
- Text input + send button, hint "Ask Dash anything...".
- Static disclaimer line under the input: "Dash is an AI assistant and can
  make mistakes."

**Answer engine**
- Chip tap or submitted free text → add as a user message → short
  `Future.delayed` "thinking" pause (mirrors existing `_AIChatScreen`
  behavior) → keyword match against the four quick topics, then the
  migrated `_faqData`, then a generic fallback reply.
- "Talk to a human" (chip or matched free text) short-circuits the reply
  path and calls the WhatsApp launch helper instead of adding a text
  reply.

## Data flow & error handling

No network calls are introduced by this phase. `DashViewModel` only touches
in-memory state, the static FAQ dataset, and the existing WhatsApp
`url_launcher` helper — which already handles launch failures (existing
fallback behavior in `help_support_view.dart` is reused as-is, not
reimplemented).

## Testing

- Widget test: `DashBubble` renders with/without the nudge dot; tapping it
  opens `DashSheet`; the dot disappears after first open.
- Widget test: each of the four FAQ chips produces its expected canned
  reply.
- Widget test: free-text keyword matching returns the same reply as the
  matching chip for representative inputs; an unmatched query returns the
  generic fallback.
- Widget test: "Talk to a human" (chip and matched free text) triggers the
  WhatsApp launch call (mocked `url_launcher`).
- Widget test: Help & Support's "AI Chat" tile opens `DashSheet`, not the
  old full-screen route.
- Manual check: bubble renders bottom-right on all four main tabs without
  overlapping the dialer FAB, on at least one small and one large device
  size.
