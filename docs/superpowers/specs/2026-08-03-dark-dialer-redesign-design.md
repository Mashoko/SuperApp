# Dark Dialer UI Redesign — Design Spec

Date: 2026-08-03
Status: Approved, pending implementation plan

## Context

The user supplied a reference screenshot of a target visual design (dark
indigo/purple gradient background, floating glass keypad panel, 3-tab
floating glass nav bar) and asked for the Phone/Dialer screen to be rebuilt
to match, plus two related changes: a trimmed/renamed bottom nav, and real
device-contacts wiring.

A code audit (not guesswork) before designing found:

- **The actual "Phone/Dialer screen" is `DialpadView`**
  (`lib/features/dialpad/presentation/views/dialpad_view.dart`), opened as
  a modal bottom sheet from Home's dial button
  (`home_view.dart`'s `_openDialpadSheet`, at 90% screen height, rounded
  top corners, white background). It hosts its own internal 4-tab
  structure (Phone/Recents/Contacts/Speed Test) via a `_selectedIndex`
  switch and a plain white `BottomNavigationBar` — this is what the
  reference screenshot's floating-panel-over-gradient aesthetic matches.
  `CallingView` (a separate, full-screen alternative with its own
  Dialer/Recents/Contacts/Speed Test tabs, reachable from Home's "Calling"
  tile) is a different screen and is **out of scope** for this work.
- **Contacts already pull from real device contacts.** `flutter_contacts`
  and `permission_handler` are both already `pubspec.yaml` dependencies,
  and `ContactsView`
  (`lib/features/contacts/presentation/views/contacts_view.dart`) already
  requests permission, loads real contacts, and has a tap-to-call/
  copy-to-dialpad bottom sheet. This work is an **enhancement**, not a
  rebuild: alphabetical sort + section headers, a distinct
  "permanently denied" state with a Settings-deep-link button, and
  pull-to-refresh are missing; the visual style is currently plain light
  Material and will be restyled to match.
- **No "Market Place" route or module exists anywhere in this codebase**
  (verified via grep). Home's own bottom nav already has a "Shop" tab
  routing to `Routes.shopping` (`ShoppingView`) — confirmed with the user
  that this is the intended "Market Place" destination.
- **No DTMF tone-playback logic exists today** in the dialpad feature —
  the request's "no regression to DTMF tones" has nothing to preserve;
  none is being added (out of scope, not requested).
- Home already has a polished glass nav bar component (`GlassBottomNav`,
  `lib/features/home/presentation/widgets/glass_bottom_nav.dart`), but it
  explicitly assumes **exactly 4 tabs plus a centered floating dial-PAD
  button** (documented in its own doc comment). The dialer's new nav needs
  exactly 3 tabs and no PAD. Rather than bending that shared,
  already-in-use component to fit a shape it wasn't built for, this design
  introduces a small new widget that reuses the same `WunzaColors` tokens
  for visual consistency, keeping blast radius to the dialer only.

## Goals

- `DialpadView`'s visuals match the reference screenshot: dark gradient
  background, floating rounded-glass keypad panel, restyled top bar,
  keypad, and call/delete action row.
- The dialer's internal nav bar is trimmed from 4 tabs
  (Phone/Recents/Contacts/Speed Test) to 3 (Recents/Contacts/Market
  Place), restyled as a dark floating glass pill with cyan/teal active
  styling, consistent with the app's existing glass-nav visual language.
- Contacts screen gets the same dark glass visual treatment, plus real
  permission-state handling (denied vs. permanently-denied vs. granted),
  alphabetical sort with section headers, and pull-to-refresh.
- No regressions to call-placing, number entry/formatting, or
  account-balance/recents data logic — only the visual layer and the
  three items above change.

## Non-goals

- `CallingView` and its own tab set — untouched.
- `HelpSupportView`, `SipCallManager`, `Routes`, `DialpadViewModel`'s
  balance/recents/call logic — untouched.
- Adding DTMF tone playback — none exists today; not being added.
- Extending or modifying `GlassBottomNav` (Home's own nav bar) — a new,
  separate, smaller widget is used instead.
- Consolidating `DialpadView` and `CallingView` — out of scope, as with
  the earlier Call Logs Overhaul plan.
- Golden-image/pixel-diff testing of the new visuals — brittle, low value
  for a one-off screen redesign. See Testing section.

## Architecture

### Ownership split: `DialpadView` vs. `home_view.dart`

`DialpadView` owns its entire visual redesign internally — background
gradient, glass panel, keypad, and the new nav bar. `home_view.dart`'s
`_openDialpadSheet` wrapper `Container` keeps providing the rounded-top
clip shape (`BorderRadius.vertical(top: Radius.circular(30))`) but its
`color: Colors.white` becomes `Colors.transparent`, letting `DialpadView`'s
own `Scaffold` (itself `backgroundColor: Colors.transparent` with a
gradient `Container` behind everything) paint the actual pixels. This is a
one-line change in `home_view.dart`; everything else is internal to
`DialpadView`.

### Screen-state model

`DialpadView`'s existing `int _selectedIndex` (0–3, Phone/Recents/
Contacts/SpeedTest) is replaced with:

```dart
enum _DialerSection { keypad, recents, contacts }
```

starting at `_DialerSection.keypad`. `_buildBody` switches on this enum;
the `SpeedTestView` case is removed entirely (see Cleanup).

- **Keypad** is the sheet's initial content only. Once the user taps
  Recents or Contacts, that content replaces the keypad in the sheet's
  content area for the remainder of that sheet's lifetime — there is no
  nav-bar path back to the keypad. Reopening the sheet (via Home's dial
  button) always starts fresh at the keypad. This was confirmed with the
  user as the intended behavior (matches the reference screenshot showing
  "Recents" highlighted while the keypad is visible, without needing a
  4th "keypad" tab).
- **Market Place** does not change `_selectedIndex`/`_DialerSection` at
  all. Tapping it calls `Navigator.pop(context)` (closing the sheet) then
  `Navigator.pushNamed(context, Routes.shopping)`.

### New widget: `DialerGlassNav`

New file: `lib/features/dialpad/presentation/widgets/dialer_glass_nav.dart`.

- Exactly 3 fixed tabs: Recents (clock icon), Contacts (person icon),
  Market Place (`Icons.storefront_outlined`/`Icons.storefront`, matching
  Home's own "Shop" tab iconography for consistency).
- Visual: dark translucent pill using the same tokens as `GlassBottomNav`
  (`WunzaColors.navGlassDark`, backdrop blur, rounded shape, subtle
  border) — its own small widget, no PAD button, no quick-action fan, no
  4-tab assumption.
- Active tab styling: cyan/teal (~`#4DD8E0`) icon + label. A new color
  token is added to `theme.dart` alongside the existing violet
  `WunzaColors.navIndicator` — e.g. `WunzaColors.dialerNavIndicator =
  Color(0xFF4DD8E0)` — since this screen's accent is explicitly cyan/teal
  per the reference, distinct from the violet used by `GlassBottomNav`
  elsewhere. Inactive tabs: muted gray, matching `GlassBottomNav`'s
  existing inactive treatment.
- `activeIndex` reflects `_DialerSection`: renders as "Recents highlighted"
  when section is `keypad` or `recents`; "Contacts highlighted" when
  section is `contacts`. Tapping Market Place doesn't touch this state —
  it invokes a passed-in `onMarketPlaceTap` callback.

### Visual redesign details (`DialpadView`)

- **Background:** `Scaffold(backgroundColor: Colors.transparent)`, with a
  full-bleed `Container` behind all content painting a top-to-bottom
  `LinearGradient` from `#2A1F4D` to `#0B0A17`.
- **Glass panel:** `Container` with `BorderRadius.circular(32)`, fill
  `rgba(255,255,255,0.04)` (`Color(0x0AFFFFFF)`), inset with margin on all
  sides from the gradient edges. Houses the top bar, number display, and
  keypad.
- **Top bar (inside panel):** left — circular ghost `IconButton` (search
  icon, translucent fill), reusing the existing no-op search callback.
  Center — the existing `AnimatedSwitcher`-driven voice-balance/
  account-balance two-line text, restyled to small muted-gray, centered;
  data logic (`viewModel.voiceBalance`/`accountBalance`) unchanged. Right —
  circular ghost button opening the existing `PopupMenuButton`
  (Account/About/Refresh), restyled to match, same `onSelected` logic.
- **Number entry:** centered text, generous top padding, thin font
  weight, no visible box/underline, driven by the existing
  `_textController.text` (single source of truth, unchanged). When empty,
  render the literal string `"Enter number"` in light gray; when
  non-empty, render `_textController.text` itself (the entered digits) in
  a brighter/white weight. This is a conditional on the same text widget,
  not two separate widgets or a real `TextField` placeholder.
- **Keypad:** 4×3 grid of circles (existing `_buildNumPadGrid`/
  `_buildKeypadButton` structure retained, restyled): `rgba(255,255,255,
  0.08)` fill, no border, subtle inner-highlight `BoxShadow`. White digit,
  muted-gray letter subtext beneath (unchanged `subLabels` map). Tap
  logic (`_handleNum`) unchanged.
- **Action row:** Call button — larger circle, new purple→blue diagonal
  gradient (new tokens, e.g. `WunzaColors.dialerCallGradientStart`/`End`,
  distinct from Home's coral/pink dial-PAD gradient since it's a
  different affordance), white phone icon, same `_handleCall(true)`
  wiring. Delete button — smaller ghost circle beside it, muted backspace
  icon, rendered only when `_textController.text.isNotEmpty` (same
  conditional as today, repositioned per the reference to sit beside the
  call button rather than inline with the number display).

## Contacts (`ContactsView`)

Enhancement of existing, already-functional real-device-contacts code —
not a rebuild.

- **Sorting/headers:** sort fetched `Contact`s by `displayName`
  (case-insensitive), group into a `Map<String, List<Contact>>` keyed by
  uppercased first letter, render via a `ListView` with plain `Container`
  section-header rows per letter group (no new sticky-header package).
- **Permission states:** replace the single `_permissionDenied` bool with
  a state derived from `permission_handler`'s `Permission.contacts.status`
  (already a dependency), distinguishing `PermissionStatus.denied` from
  `PermissionStatus.permanentlyDenied`. Both render an empty state with a
  "Grant Access" button: for plain-denied, the button re-requests via
  `Permission.contacts.request()`; for permanently-denied, it calls
  `openAppSettings()` (from `permission_handler`).
- **Pull-to-refresh:** wrap the contact list in a `RefreshIndicator`
  calling the existing `_fetchContacts()`.
- **In-memory caching:** already effectively satisfied — `_contacts`
  lives in `State` for the widget's session lifetime; no change needed.
- **Tap behavior:** unchanged. The existing bottom sheet with "Call" /
  "Copy to Dialpad" options stays exactly as-is.
- **Visual restyle:** same dark-gradient/glass-panel treatment as the
  dialer, reusing the same background/panel building blocks introduced
  there, so the screen reads as continuous with the dialer when reached
  via `DialerGlassNav`.

## Cleanup

- Delete `lib/features/speed_test/presentation/views/speed_test_view.dart`
  — confirmed via grep to have exactly one reference (the now-removed
  import in `DialpadView`); becomes fully orphaned once that reference is
  removed. `CallingView`'s separate speed-test tab/file
  (`lib/features/calling/presentation/views/tabs/speed_test_view.dart`)
  is a distinct file and is untouched.

## Testing

Per this session's established convention: `dart analyze` plus targeted
tests where they add real value, no full `flutter test` suite or
`flutter build` run.

- Unit test for `_DialerSection` transition logic if it's extracted as a
  small pure/testable piece (keypad → recents/contacts, no path back);
  otherwise covered by direct code reading given its small size.
- Unit tests for the Contacts permission-state branching (denied vs.
  permanently-denied vs. granted) and for the alphabetical
  grouping/sorting logic, extracted as a pure function
  (`Map<String, List<Contact>> groupContactsByLetter(List<Contact>)` or
  similar) so it's testable without a live device-contacts plugin call,
  mirroring this session's established `resolveOnFetch`/
  `resolveCallLogStatus` precedent of extracting pure, side-effect-free
  helpers for testability.
- No golden-image/pixel-diff tests of the new visuals.
- Manual verification (device/emulator, environment-blocked in this
  sandbox per this session's established precedent): keypad entry, call
  placement, backspace, tab switching to Recents/Contacts, Market Place
  navigation, contacts permission flow (grant/deny/permanently-deny/
  Settings deep link), pull-to-refresh.
