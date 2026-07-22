# Dash Chat Assistant (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a floating "Dash" chat bubble, reachable from every main tab, that opens a bottom sheet with FAQ chips and free-text keyword-matched canned answers — replacing the existing full-screen "AI Assistant" buried in Help & Support.

**Architecture:** A new `dash` feature module (`DashViewModel` + `DashBubble` + `DashSheet`) is added to the existing `get_it` + `provider` (ChangeNotifier) stack the app already uses for every other view model. `DashBubble` is placed in `home_view.dart`'s outer `Stack` so it renders above all four tabs. The FAQ dataset backing both Dash and Help & Support's existing FAQ browser is extracted from `help_support_view.dart` into a shared public file so there is one source of truth. The old `_AIChatScreen` is deleted; Help & Support's "AI Chat" tile becomes another entry point into the same `DashSheet`.

**Tech Stack:** Flutter, `provider` (ChangeNotifier view models), `get_it` (DI), `url_launcher` (WhatsApp escalation, already in use).

## Global Constraints

- Package name is `mvvm_sip_demo` — imports in `lib/features/home/**` use `package:mvvm_sip_demo/...` style; imports in `lib/core/di/inject.dart` and other `lib/core/**`/`lib/features/**` files use relative `../../` style. Match whichever style the file you're editing already uses.
- Brand colors (already defined in `lib/core/theme.dart`, do not redefine): `WunzaColors.glidePrimary` = `Color(0xFF4A148C)` (deep purple, bubble/header), `WunzaColors.glideAccent` = `Color(0xFFFF6D00)` (vibrant orange, nudge dot).
- Exact FAQ chip labels (must match verbatim, used both as UI labels and as the text fed into keyword matching): `"Check data balance"`, `"How do I top up?"`, `"Bundle prices"`, `"Talk to a human"`.
- Exact disclaimer copy: `"Dash is an AI assistant and can make mistakes."`
- Exact empty-state greeting: `"Hi! I'm Dash 👋 I can help with balances, bundles, billing questions and more. What do you need?"`
- Phase 1 scope only: no live balance/bundle data, no LLM/network backend for answers — everything is static/local keyword matching. Do not wire `AccountSummaryViewModel.paymentsBalance` or `PaymentsClient` into any Dash reply text.
- Chat history is session-scoped (in-memory only) — no persistence to disk/prefs.
- Run `dart analyze` after every task that touches Dart files; it must report "No issues found!" before moving to the next task.

---

### Task 1: Extract shared FAQ data model + dataset

**Files:**
- Create: `lib/features/help_support/data/faq_data.dart`
- Modify: `lib/features/help_support/presentation/views/help_support_view.dart:20-132` (remove private model classes + dataset, add import), and rename usages at lines 203, 267, 278, 306, 307, 518, 523, 672-680 (inside `_AIChatScreen`, still present at this point), 1148, 1200, 1207

**Interfaces:**
- Produces: `FaqItem` (fields `question: String`, `answer: String`), `FaqCategory` (fields `title: String`, `icon: IconData`, `color: Color`, `items: List<FaqItem>`), and `const faqData = <FaqCategory>[...]` — all public, importable from `lib/features/help_support/data/faq_data.dart`. Task 2 (`DashViewModel`) consumes `faqData` and `FaqItem`.

- [ ] **Step 1: Create the shared FAQ data file**

Create `lib/features/help_support/data/faq_data.dart` with this exact content (models renamed from `_FaqItem`/`_FaqCategory` to public `FaqItem`/`FaqCategory`; dataset renamed from `_faqData` to public `faqData`; content copied verbatim from the current `help_support_view.dart:29-132`):

```dart
import 'package:flutter/material.dart';

class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

class FaqCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<FaqItem> items;
  const FaqCategory({required this.title, required this.icon, required this.color, required this.items});
}

const faqData = [
  FaqCategory(title: 'Payments', icon: Icons.payment_outlined, color: Color(0xFF185FA5), items: [
    FaqItem('Why is my payment pending?', 'Payments can take up to 24 hours to process depending on your bank or mobile money provider. If it has been longer than 24 hours, please use the Report a Problem form and attach your transaction receipt.'),
    FaqItem('My payment failed — what now?', 'Check that your card or wallet has sufficient funds and that your payment method is active. Try again or use an alternative method. If the issue persists, tap Report a Problem.'),
    FaqItem('I was charged twice', 'Duplicate charges are reversed automatically within 2 business days. If you have not received a refund after 3 days, contact our support team with the duplicate transaction IDs.'),
    FaqItem('What is the refund policy?', 'Digital services (calls, airtime) are non-refundable once delivered. Shopping orders can be refunded within 7 days of delivery if the item is unused and in original condition.'),
    FaqItem('My card was declined', 'Ensure your card is enabled for online payments. Some cards block international or digital transactions by default — contact your bank to enable them.'),
    FaqItem('What are the transaction limits?', 'Daily limits vary by payment method. EcoCash: \$500/day. Bank cards: \$2,000/day. Wallet transfers: \$1,000/day. Contact support to request a limit increase.'),
  ]),
  FaqCategory(title: 'Shopping', icon: Icons.shopping_bag_outlined, color: Color(0xFF9C27B0), items: [
    FaqItem('How do I track my order?', 'Go to Profile → My Orders and tap on your order. You will see the real-time status and estimated delivery date.'),
    FaqItem('My order has not arrived', 'Check the tracking status in My Orders. If the delivery window has passed, tap Report a Problem and select Shopping to raise an investigation.'),
    FaqItem('How do I return an item?', 'Visit My Orders, tap the order, and select Return Item. Returns must be requested within 7 days of delivery. The seller will arrange collection.'),
    FaqItem('Can I cancel my order?', 'Orders can be cancelled within 30 minutes of placement before they are confirmed by the seller. Go to My Orders → Cancel Order.'),
    FaqItem('I received the wrong item', 'Take a photo of the received item and tap Report a Problem → Shopping → Wrong Item Received. We will arrange a replacement or refund.'),
    FaqItem('Where is my refund?', 'Approved refunds are processed within 3–5 business days back to your original payment method.'),
  ]),
  FaqCategory(title: 'Calling & Airtime', icon: Icons.call_outlined, color: Color(0xFF00BCD4), items: [
    FaqItem('How do I buy airtime?', 'Tap the Calling tab → Buy Airtime, enter the amount and recipient number, then confirm payment.'),
    FaqItem('I sent airtime to the wrong number', 'Airtime transfers are instant and cannot be reversed. Please double-check the number before confirming a transfer.'),
    FaqItem('Poor call quality', 'VoIP call quality depends on your internet connection. For best results use Wi-Fi or a strong 4G signal. Try toggling airplane mode to reset your connection.'),
    FaqItem('My calls are dropping', 'Check your internet speed (minimum 1 Mbps for calls). If the issue persists, go to Account Services and re-register your SIP account.'),
    FaqItem('International calls not connecting', 'Ensure your account has sufficient balance and that the destination number is formatted correctly with the country code (e.g. +44 for UK).'),
    FaqItem('I was not credited after recharge', 'Wait 5 minutes and pull-to-refresh your balance. If the credit still has not appeared, report the issue with your voucher PIN and transaction reference.'),
  ]),
  FaqCategory(title: 'Wallet', icon: Icons.account_balance_wallet_outlined, color: Color(0xFF4CAF50), items: [
    FaqItem('How do I deposit into my wallet?', 'Tap Payment Methods → Add Funds and choose EcoCash, OneMoney, or bank transfer. Deposits reflect within minutes.'),
    FaqItem('How do I withdraw from my wallet?', 'Tap Wallet → Withdraw and select your bank account or mobile money number. Withdrawals take 1–2 business days.'),
    FaqItem('My wallet balance is incorrect', 'Pull down to refresh your wallet. If the balance is still wrong after refreshing, contact support with the specific transaction ID.'),
    FaqItem('Can I send money to another user?', 'Wallet transfers between app users are instant. Tap Wallet → Transfer and enter the recipient\'s phone number.'),
    FaqItem('What are the wallet limits?', 'The daily spending limit is \$2,000 and the wallet balance cap is \$5,000. Contact support to request an increase.'),
    FaqItem('Why is my wallet frozen?', 'Wallets are temporarily frozen after suspicious activity is detected. Tap Emergency → Unfreeze Account or contact support directly.'),
  ]),
  FaqCategory(title: 'Utility Bills', icon: Icons.bolt_outlined, color: Color(0xFFFF9800), items: [
    FaqItem('How do I pay ZESA?', 'Tap Bills → Electricity → ZESA, enter your meter number and amount, then confirm payment. The token is delivered by SMS.'),
    FaqItem('I paid but did not receive my ZESA token', 'Tokens are usually delivered within 2 minutes. Check your SMS inbox. If not received after 10 minutes, tap Report a Problem → Utility Bills.'),
    FaqItem('Can I pay bills for someone else?', 'Yes. During payment, enter the recipient\'s account number or meter number instead of your own.'),
    FaqItem('Which utility providers are supported?', 'ZESA, ZINWA, DSTV, ZOL, TelOne, NetOne, Econet, Municipality rates, and selected school fees.'),
    FaqItem('My bill payment is pending', 'Some payments to utility providers take up to 30 minutes to process. If it is pending for more than 1 hour, report the issue with your reference number.'),
    FaqItem('Can I set up recurring bill payments?', 'Recurring payments are coming soon. You will be notified when the feature is available.'),
  ]),
  FaqCategory(title: 'Account & Security', icon: Icons.security_outlined, color: Color(0xFFE53935), items: [
    FaqItem('How do I reset my PIN?', 'Tap Profile → Account Services → Reset PIN. You will receive an OTP on your registered phone number to verify your identity.'),
    FaqItem('How do I change my phone number?', 'Phone number changes require identity verification. Contact support with a copy of your ID and proof of ownership of the new number.'),
    FaqItem('I cannot log in to my account', 'Tap Forgot Password on the login screen to reset via OTP. If you no longer have access to your registered number, contact support immediately.'),
    FaqItem('How do I enable two-factor authentication?', 'Go to Profile → Settings → Security → Two-Factor Authentication and follow the setup steps.'),
    FaqItem('I suspect unauthorized access to my account', 'Immediately tap Emergency → Account Compromised. This will lock your account and alert our security team.'),
    FaqItem('How do I delete my account?', 'Account deletion requests must be submitted in writing to support@firststreet.co.zw with your full name and registered phone number.'),
  ]),
  FaqCategory(title: 'General', icon: Icons.help_outline, color: Color(0xFF607D8B), items: [
    FaqItem('What is First Street?', 'First Street is a super app providing calling, shopping, utility bill payments, and wallet services across Zimbabwe and the region.'),
    FaqItem('Is my data secure?', 'Yes. All data is encrypted in transit and at rest. We comply with applicable data protection regulations and never sell your personal information.'),
    FaqItem('How do I update the app?', 'Open the Google Play Store or Apple App Store and search for First Street to download the latest version.'),
    FaqItem('The app is crashing', 'Try force-closing and reopening the app. If the issue continues, uninstall and reinstall from the store. If it still crashes, report the issue.'),
    FaqItem('How do I contact support?', 'Use any channel on the Help & Support screen: WhatsApp, live chat, email, or phone. WhatsApp is the fastest.'),
    FaqItem('What are support hours?', 'WhatsApp and chat: 24/7. Phone support: Monday–Friday 08:00–17:00 CAT. Email: responses within 24 hours.'),
  ]),
];
```

- [ ] **Step 2: Remove the duplicate model classes and dataset from `help_support_view.dart`**

In `lib/features/help_support/presentation/views/help_support_view.dart`, delete lines 29-41 (the `_FaqItem` and `_FaqCategory` class definitions) and delete lines 75-132 (the `_faqData` constant, including its opening `// ─── Static content ───...` comment stays — only remove the `const _faqData = [...]` block). Add the import near the top of the file, alongside the existing local imports:

```dart
import '../../data/faq_data.dart';
```

- [ ] **Step 3: Rename every remaining reference from the private to the public names**

Apply these exact replacements in `help_support_view.dart` (each `old_string` below is unique in the file — match and replace exactly, do not use a blind find-replace of the bare token `_FaqCategory`, since that string is also a substring of the unrelated class name `_FaqCategoryScreen` which must NOT be renamed):

```
_FaqCategory? _activeFaqCategory;          →  FaqCategory? _activeFaqCategory;
final void Function(_FaqCategory) onFaqCategory;   →  final void Function(FaqCategory) onFaqCategory;
List<_FaqItem> _searchResults = [];        →  List<FaqItem> _searchResults = [];
final results = <_FaqItem>[];              →  final results = <FaqItem>[];
for (final cat in _faqData) {              →  for (final cat in faqData) {          (appears twice: once in _MainScreenState._onSearch, once in _AIChatScreenState._send — rename both)
children: _faqData.map((cat) => _buildFaqCategoryRow(cat, d)).toList(),   →  children: faqData.map((cat) => _buildFaqCategoryRow(cat, d)).toList(),
Widget _buildFaqCategoryRow(_FaqCategory cat, bool d) {   →  Widget _buildFaqCategoryRow(FaqCategory cat, bool d) {
final _FaqCategory category;               →  final FaqCategory category;
final void Function(_FaqCategory) onFaqTap;   →  final void Function(FaqCategory) onFaqTap;
final faqCat = _faqData.where((c) => c.title.toLowerCase().contains(service.name.toLowerCase().split(' ').first)).firstOrNull;   →  final faqCat = faqData.where((c) => c.title.toLowerCase().contains(service.name.toLowerCase().split(' ').first)).firstOrNull;
```

Also rename the two remaining references inside `_AIChatScreenState._send` (around the current lines 672-673 in the un-edited file: `_FaqItem? match;` and the `for (final cat in _faqData)` loop) to `FaqItem? match;` and `for (final cat in faqData)`. (This class is deleted entirely in Task 7, but it must keep compiling until then.)

- [ ] **Step 4: Verify it compiles**

Run: `dart analyze lib/features/help_support/presentation/views/help_support_view.dart lib/features/help_support/data/faq_data.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/help_support/data/faq_data.dart lib/features/help_support/presentation/views/help_support_view.dart
git commit -m "refactor(help-support): extract FAQ data to a shared public file"
```

---

### Task 2: `DashViewModel` — message state + keyword-matching answer engine

**Files:**
- Create: `lib/features/dash/presentation/viewmodels/dash_viewmodel.dart`
- Test: `test/features/dash/dash_viewmodel_test.dart`

**Interfaces:**
- Consumes: `faqData` and `FaqItem` from `lib/features/help_support/data/faq_data.dart` (Task 1).
- Produces: `class DashMessage { final String text; final bool isUser; }`, `class DashViewModel extends ChangeNotifier` with:
  - `List<DashMessage> get messages`
  - `bool get thinking`
  - `bool get showNudge`
  - `void dismissNudge()`
  - `Future<void> submit(String text)` — adds the user message, sets `thinking`, waits, appends the matched reply, clears `thinking`
  - `bool consumeEscalation()` — returns and clears a one-shot "should escalate to a human" flag set by the most recent `submit()`
  Task 5 (`DashSheet`) and Task 4 (`DashBubble`) consume this exact API.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dash/dash_viewmodel_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/viewmodels/dash_viewmodel.dart';

void main() {
  group('DashViewModel', () {
    test('starts with no messages and the nudge shown', () {
      final vm = DashViewModel();
      expect(vm.messages, isEmpty);
      expect(vm.showNudge, isTrue);
      expect(vm.thinking, isFalse);
    });

    test('dismissNudge hides the nudge and notifies listeners', () {
      final vm = DashViewModel();
      var notified = false;
      vm.addListener(() => notified = true);
      vm.dismissNudge();
      expect(vm.showNudge, isFalse);
      expect(notified, isTrue);
    });

    test('submit adds a user message then an assistant reply', () async {
      final vm = DashViewModel();
      await vm.submit('Check data balance');
      expect(vm.messages.length, 2);
      expect(vm.messages[0].isUser, isTrue);
      expect(vm.messages[0].text, 'Check data balance');
      expect(vm.messages[1].isUser, isFalse);
      expect(vm.thinking, isFalse);
    });

    test('data balance chip text returns the data-balance reply', () async {
      final vm = DashViewModel();
      await vm.submit('Check data balance');
      expect(vm.messages[1].text, contains('Data'));
    });

    test('top up chip text returns the top-up reply', () async {
      final vm = DashViewModel();
      await vm.submit('How do I top up?');
      expect(vm.messages[1].text, contains('Top Up'));
    });

    test('bundle prices chip text returns the bundle reply', () async {
      final vm = DashViewModel();
      await vm.submit('Bundle prices');
      expect(vm.messages[1].text, contains('Data'));
    });

    test('talk to a human sets the escalation flag and is consumed once', () async {
      final vm = DashViewModel();
      await vm.submit('Talk to a human');
      expect(vm.consumeEscalation(), isTrue);
      expect(vm.consumeEscalation(), isFalse);
    });

    test('free text matching a keyword behaves like the matching chip', () async {
      final vm = DashViewModel();
      await vm.submit('can you check my data please');
      expect(vm.messages[1].text, contains('Data'));
    });

    test('free text matching an FAQ question returns that answer', () async {
      final vm = DashViewModel();
      await vm.submit('How do I pay ZESA?');
      expect(vm.messages[1].text, contains('ZESA'));
    });

    test('unmatched free text returns the generic fallback', () async {
      final vm = DashViewModel();
      await vm.submit('xyzzy unrelated gibberish');
      expect(vm.messages[1].text, contains('talk to a human'));
      expect(vm.consumeEscalation(), isFalse);
    });

    test('empty submission is a no-op', () async {
      final vm = DashViewModel();
      await vm.submit('   ');
      expect(vm.messages, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dash/dash_viewmodel_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'mvvm_sip_demo' in 'package:mvvm_sip_demo/features/dash/presentation/viewmodels/dash_viewmodel.dart'.` (file doesn't exist yet)

- [ ] **Step 3: Implement `DashViewModel`**

Create `lib/features/dash/presentation/viewmodels/dash_viewmodel.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../../help_support/data/faq_data.dart';

class DashMessage {
  final String text;
  final bool isUser;
  const DashMessage({required this.text, required this.isUser});
}

class _DashReply {
  final String text;
  final bool escalate;
  const _DashReply(this.text, {this.escalate = false});
}

class DashViewModel extends ChangeNotifier {
  final List<DashMessage> _messages = [];
  List<DashMessage> get messages => List.unmodifiable(_messages);

  bool _thinking = false;
  bool get thinking => _thinking;

  bool _nudgeDismissed = false;
  bool get showNudge => !_nudgeDismissed;

  bool _escalate = false;

  void dismissNudge() {
    if (_nudgeDismissed) return;
    _nudgeDismissed = true;
    notifyListeners();
  }

  Future<void> submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _messages.add(DashMessage(text: trimmed, isUser: true));
    _thinking = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    final reply = _matchReply(trimmed);
    _messages.add(DashMessage(text: reply.text, isUser: false));
    _thinking = false;
    _escalate = reply.escalate;
    notifyListeners();
  }

  bool consumeEscalation() {
    final escalate = _escalate;
    _escalate = false;
    return escalate;
  }

  _DashReply _matchReply(String query) {
    final q = query.toLowerCase();

    if (_containsAny(q, const ['human', 'agent', 'person', 'someone'])) {
      return const _DashReply(
        'Connecting you to a human agent over WhatsApp — hang tight.',
        escalate: true,
      );
    }
    if (_containsAny(q, const ['data balance', 'my data', 'data bundle', 'data'])) {
      return const _DashReply(
        'Tap the "Data" chip on your wallet card, or ask me anytime — just say "check my data".',
      );
    }
    if (_containsAny(q, const ['top up', 'topup', 'top-up', 'recharge'])) {
      return const _DashReply(
        'Tap "Top Up" on your wallet card, choose a voucher or payment method, and confirm the amount.',
      );
    }
    if (_containsAny(q, const ['bundle', 'price', 'prices', 'plan'])) {
      return const _DashReply(
        'Bundle prices are on the Data tab — tap "Data — add a bundle" on your wallet card to see current options.',
      );
    }

    for (final cat in faqData) {
      for (final item in cat.items) {
        final matchesQuestion = item.question.toLowerCase().contains(q);
        final matchesWord = q
            .split(' ')
            .any((w) => w.length > 3 && item.answer.toLowerCase().contains(w));
        if (matchesQuestion || matchesWord) {
          return _DashReply(item.answer);
        }
      }
    }

    return const _DashReply(
      'I was not able to find a specific answer for that. Tap a topic below, or talk to a human.',
    );
  }

  static bool _containsAny(String haystack, List<String> needles) =>
      needles.any(haystack.contains);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dash/dash_viewmodel_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/dash/presentation/viewmodels/dash_viewmodel.dart test/features/dash/dash_viewmodel_test.dart
git commit -m "feat(dash): add DashViewModel with keyword-matching answer engine"
```

---

### Task 3: Make the WhatsApp escalation helper reusable

**Files:**
- Modify: `lib/features/help_support/presentation/views/help_support_view.dart:474,625,1644`

**Interfaces:**
- Produces: `Future<void> openWhatsAppSupport(BuildContext context, String userName)` — public, importable from `help_support_view.dart`. Task 5 (`DashSheet`) consumes this exact signature.

- [ ] **Step 1: Rename the function definition**

In `lib/features/help_support/presentation/views/help_support_view.dart`, change:

```dart
Future<void> _openWhatsApp(BuildContext context, String userName) async {
```

to:

```dart
Future<void> openWhatsAppSupport(BuildContext context, String userName) async {
```

- [ ] **Step 2: Update both call sites in the same file**

Change both occurrences of:

```dart
onTap: () => _openWhatsApp(context, _userName)),
```

(one on the line with `label: 'WhatsApp\nSupport'`, one on the line with `label: 'WhatsApp'`) to:

```dart
onTap: () => openWhatsAppSupport(context, _userName)),
```

- [ ] **Step 3: Verify it compiles**

Run: `dart analyze lib/features/help_support/presentation/views/help_support_view.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/help_support/presentation/views/help_support_view.dart
git commit -m "refactor(help-support): expose WhatsApp escalation helper for reuse by Dash"
```

---

### Task 4: `DashBubble` widget

**Files:**
- Create: `lib/features/dash/presentation/widgets/dash_bubble.dart`
- Test: `test/features/dash/dash_bubble_test.dart`

**Interfaces:**
- Consumes: `DashViewModel` (Task 2) via `provider`'s `context.watch`/`context.read`; `WunzaColors.glidePrimary` / `WunzaColors.glideAccent` from `lib/core/theme.dart`.
- Produces: `class DashBubble extends StatelessWidget` (no constructor params besides `key`). Task 6 places this directly in `home_view.dart`'s `Stack`.
- Note: `DashBubble` calls `showDashSheet(context)` on tap — this function is defined in Task 5 (`dash_sheet.dart`). Task 4's own test does not depend on Task 5; it only verifies the bubble renders and reacts to `DashViewModel` state (see the test harness below, which does not exercise the tap handler).

- [ ] **Step 1: Write the failing test**

Create `test/features/dash/dash_bubble_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/viewmodels/dash_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/widgets/dash_bubble.dart';

Widget _harness(DashViewModel vm) {
  return ChangeNotifierProvider<DashViewModel>.value(
    value: vm,
    child: const MaterialApp(home: Scaffold(body: DashBubble())),
  );
}

void main() {
  testWidgets('shows the nudge dot when the nudge has not been dismissed',
      (tester) async {
    final vm = DashViewModel();
    await tester.pumpWidget(_harness(vm));
    expect(find.byKey(const Key('dash_nudge_dot')), findsOneWidget);
  });

  testWidgets('hides the nudge dot once dismissed', (tester) async {
    final vm = DashViewModel()..dismissNudge();
    await tester.pumpWidget(_harness(vm));
    expect(find.byKey(const Key('dash_nudge_dot')), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dash/dash_bubble_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package ... dash_bubble.dart` (file doesn't exist yet)

- [ ] **Step 3: Implement `DashBubble`**

Create `lib/features/dash/presentation/widgets/dash_bubble.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme.dart';
import '../viewmodels/dash_viewmodel.dart';
import 'dash_sheet.dart';

class DashBubble extends StatelessWidget {
  const DashBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final showNudge = context.watch<DashViewModel>().showNudge;
    return GestureDetector(
      onTap: () => showDashSheet(context),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: WunzaColors.glidePrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
            if (showNudge)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  key: const Key('dash_nudge_dot'),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: WunzaColors.glideAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

Note: this file imports `dash_sheet.dart`, which does not exist until Task 5. Create a temporary placeholder so Task 4 compiles standalone: create `lib/features/dash/presentation/widgets/dash_sheet.dart` with just:

```dart
import 'package:flutter/material.dart';

Future<void> showDashSheet(BuildContext context) async {}
```

(Task 5 replaces this placeholder with the real implementation.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dash/dash_bubble_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/dash/presentation/widgets/dash_bubble.dart lib/features/dash/presentation/widgets/dash_sheet.dart test/features/dash/dash_bubble_test.dart
git commit -m "feat(dash): add DashBubble floating action widget"
```

---

### Task 5: `DashSheet` widget (header, messages, chips, input, disclaimer)

**Files:**
- Modify (replace placeholder): `lib/features/dash/presentation/widgets/dash_sheet.dart`
- Test: `test/features/dash/dash_sheet_test.dart`
- Modify: `pubspec.yaml` (add a dev dependency needed for the escalation test)

**Interfaces:**
- Consumes: `DashViewModel` (Task 2, via `provider`), `openWhatsAppSupport` (Task 3, from `help_support_view.dart`), `AccountSummaryViewModel.alias` (existing, from `lib/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart`).
- Produces: `Future<void> showDashSheet(BuildContext context)`, `class DashSheet extends StatefulWidget`. Task 6 wires `showDashSheet` into `home_view.dart` and `help_support_view.dart`.

- [ ] **Step 1: Add the test-only platform fake dependency**

In `pubspec.yaml`, under `dev_dependencies:`, add:

```yaml
  url_launcher_platform_interface: ^2.3.2
```

Run: `flutter pub get`
Expected: resolves cleanly (this package is already a transitive dependency of `url_launcher`, so no version conflicts).

- [ ] **Step 2: Write the failing tests**

Create `test/features/dash/dash_sheet_test.dart`. `AccountSummaryViewModel`'s constructor requires an `OtpAuthService` and a `PaymentsClient` (`lib/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart:14`: `AccountSummaryViewModel(this._authService, this._paymentsClient);`) because `DashSheet._submit` reads `AccountSummaryViewModel.alias` for the WhatsApp message. This test never calls `loadCurrentUser()`/`fetchBalance()`, so neither dependency's gRPC methods are ever invoked — constructing them directly with a dummy `packageId` is safe (channel construction performs no network I/O), no fakes needed:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/viewmodels/dash_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dash/presentation/widgets/dash_sheet.dart';
import 'package:mvvm_sip_demo/payments_client.dart';
import 'package:mvvm_sip_demo/users_client.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

Widget _harness(DashViewModel dashVm) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DashViewModel>.value(value: dashVm),
      ChangeNotifierProvider<AccountSummaryViewModel>(
        create: (_) => AccountSummaryViewModel(
          OtpAuthService(UsersClient(packageId: 'test')),
          PaymentsClient(packageId: 'test'),
        ),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SizedBox.shrink()),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester, DashViewModel dashVm) async {
  await tester.pumpWidget(_harness(dashVm));
  final context = tester.element(find.byType(Scaffold));
  unawaited(showDashSheet(context));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeUrlLauncher fakeLauncher;

  setUp(() {
    fakeLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
  });

  testWidgets('shows the empty-state greeting when there are no messages',
      (tester) async {
    await _openSheet(tester, DashViewModel());
    expect(find.textContaining("Hi! I'm Dash"), findsOneWidget);
  });

  testWidgets('shows the disclaimer under the input', (tester) async {
    await _openSheet(tester, DashViewModel());
    expect(
      find.text('Dash is an AI assistant and can make mistakes.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping the "Check data balance" chip adds a user message and a reply',
      (tester) async {
    await _openSheet(tester, DashViewModel());
    await tester.tap(find.text('Check data balance'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Check data balance'), findsWidgets);
    expect(find.textContaining('Data'), findsWidgets);
  });

  testWidgets('tapping "Talk to a human" launches WhatsApp support',
      (tester) async {
    await _openSheet(tester, DashViewModel());
    await tester.tap(find.text('Talk to a human'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(fakeLauncher.launchedUrls, isNotEmpty);
    expect(fakeLauncher.launchedUrls.single, contains('wa.me'));
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/dash/dash_sheet_test.dart`
Expected: FAIL — the placeholder `showDashSheet` from Task 4 does nothing, so no sheet content is found (`findsOneWidget` fails with 0 widgets found).

- [ ] **Step 4: Implement `DashSheet`, replacing the Task 4 placeholder**

Replace the entire contents of `lib/features/dash/presentation/widgets/dash_sheet.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme.dart';
import '../../../account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import '../../../help_support/presentation/views/help_support_view.dart'
    show openWhatsAppSupport;
import '../viewmodels/dash_viewmodel.dart';

const _dashChips = [
  'Check data balance',
  'How do I top up?',
  'Bundle prices',
  'Talk to a human',
];

Future<void> showDashSheet(BuildContext context) {
  context.read<DashViewModel>().dismissNudge();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const DashSheet(),
  );
}

class DashSheet extends StatefulWidget {
  const DashSheet({super.key});

  @override
  State<DashSheet> createState() => _DashSheetState();
}

class _DashSheetState extends State<DashSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submit(String text) async {
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    final dashVm = context.read<DashViewModel>();
    final userName = context.read<AccountSummaryViewModel>().alias ?? 'there';

    await dashVm.submit(text);
    if (!mounted) return;

    if (dashVm.consumeEscalation()) {
      await openWhatsAppSupport(context, userName);
    }
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashVm = context.watch<DashViewModel>();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: dashVm.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            dashVm.messages.length + (dashVm.thinking ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == dashVm.messages.length) {
                            return const _DashThinkingBubble();
                          }
                          final m = dashVm.messages[i];
                          return _DashChatBubble(text: m.text, isUser: m.isUser);
                        },
                      ),
              ),
              _buildChips(),
              _buildInput(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'Dash is an AI assistant and can make mistakes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x14000000))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: WunzaColors.glidePrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: WunzaColors.glidePrimary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dash',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('Online · usually replies instantly',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        "Hi! I'm Dash 👋 I can help with balances, bundles, billing questions "
        "and more. What do you need?",
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
    );
  }

  Widget _buildChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _dashChips
            .map((label) => ActionChip(
                  label: Text(label),
                  onPressed: () => _submit(label),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Ask Dash anything...',
                filled: true,
                fillColor: const Color(0xFFF4F6FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: _submit,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _submit(_ctrl.text),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: WunzaColors.glidePrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _DashChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? WunzaColors.glidePrimary : const Color(0xFFF0F3FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 18 : 4),
                  topRight: Radius.circular(isUser ? 4 : 18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashThinkingBubble extends StatelessWidget {
  const _DashThinkingBubble();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3FA),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: WunzaColors.glidePrimary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/dash/dash_sheet_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/dash/presentation/widgets/dash_sheet.dart test/features/dash/dash_sheet_test.dart
git commit -m "feat(dash): add DashSheet bottom sheet with chips, chat, and WhatsApp escalation"
```

---

### Task 6: Wire Dash into the app shell

**Files:**
- Modify: `lib/core/di/inject.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/home/presentation/views/home_view.dart:182-201`

**Interfaces:**
- Consumes: `DashViewModel` (Task 2), `DashBubble` (Task 4).
- Produces: `getIt<DashViewModel>()` resolvable app-wide; `DashBubble` visible in the running app on all four main tabs.

- [ ] **Step 1: Register `DashViewModel` in the DI container**

In `lib/core/di/inject.dart`, add the import alongside the other feature view-model imports:

```dart
import '../../features/dash/presentation/viewmodels/dash_viewmodel.dart';
```

Add the registration next to the other `ViewModels` registrations (after the `AccountSummaryViewModel` line):

```dart
getIt.registerLazySingleton(() => DashViewModel());
```

- [ ] **Step 2: Expose it via `MultiProvider` in `main.dart`**

In `lib/main.dart`, add the import:

```dart
import 'features/dash/presentation/viewmodels/dash_viewmodel.dart';
```

Add to the `MultiProvider.providers` list (after the `AccountSummaryViewModel` entry):

```dart
ChangeNotifierProvider(create: (_) => getIt<DashViewModel>()),
```

- [ ] **Step 3: Place `DashBubble` in the home shell's Stack**

In `lib/features/home/presentation/views/home_view.dart`, add the import:

```dart
import 'package:mvvm_sip_demo/features/dash/presentation/widgets/dash_bubble.dart';
```

In the `build` method's outer `Stack`, add a new `Positioned` entry immediately after the existing bottom-nav `Positioned` block (i.e. right after the closing of the block ending `),\n          ),\n        ],\n      ),\n    );` at line 201 — insert before that final `],`):

```dart
          Positioned(
            right: 16,
            bottom: 18 + 96 + 16 + MediaQuery.of(context).padding.bottom,
            child: const DashBubble(),
          ),
```

So the full `Stack`'s `children` list ends with:

```dart
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
          Positioned(
            right: 16,
            bottom: 18 + 96 + 16 + MediaQuery.of(context).padding.bottom,
            child: const DashBubble(),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Verify it compiles and existing tests still pass**

Run: `dart analyze lib/core/di/inject.dart lib/main.dart lib/features/home/presentation/views/home_view.dart lib/features/dash`
Expected: `No issues found!`

Run: `flutter test`
Expected: all existing tests plus the new `test/features/dash/*` tests pass (no regressions).

- [ ] **Step 5: Commit**

```bash
git add lib/core/di/inject.dart lib/main.dart lib/features/home/presentation/views/home_view.dart
git commit -m "feat(dash): wire DashBubble into the app shell, visible on every main tab"
```

---

### Task 7: Retire the old full-screen AI Assistant

**Files:**
- Modify: `lib/features/help_support/presentation/views/help_support_view.dart`

**Interfaces:**
- Consumes: `showDashSheet` (Task 5).
- Produces: Help & Support's "AI Chat"/"Ask AI Assistant" tile opens `DashSheet`; `_AIChatScreen`, `_ChatBubble`, `_ThinkingBubble`, and the `_Screen.aiChat` route are deleted.

- [ ] **Step 1: Add the import**

In `lib/features/help_support/presentation/views/help_support_view.dart`, add:

```dart
import '../../../dash/presentation/widgets/dash_sheet.dart';
```

- [ ] **Step 2: Remove `aiChat` from the `_Screen` enum**

Change:

```dart
enum _Screen {
  main, aiChat, reportProblem, myTickets, ticketDetail,
  systemStatus, emergency, faqCategory, serviceHelp
}
```

to:

```dart
enum _Screen {
  main, reportProblem, myTickets, ticketDetail,
  systemStatus, emergency, faqCategory, serviceHelp
}
```

- [ ] **Step 3: Remove the `aiChat` switch case and rewire `onAiChat`**

In `_HelpSupportViewState._buildScreen`, remove:

```dart
      case _Screen.aiChat:
        return _AIChatScreen(isDark: isDark, onBack: _pop);
```

and change:

```dart
          onAiChat:       () => _push(_Screen.aiChat),
```

to:

```dart
          onAiChat:       () => showDashSheet(context),
```

- [ ] **Step 4: Rename the tile label for consistency**

Change:

```dart
      (icon: Icons.smart_toy_outlined,  label: 'Ask AI\nAssistant',   sub: 'Instant answers', color: const Color(0xFF9C27B0),
        onTap: widget.onAiChat),
```

to:

```dart
      (icon: Icons.smart_toy_outlined,  label: 'Ask Dash',   sub: 'Instant answers', color: const Color(0xFF9C27B0),
        onTap: widget.onAiChat),
```

- [ ] **Step 5: Delete the dead classes**

Delete the entire `_AIChatScreen` and `_AIChatScreenState` classes (the block starting at `class _AIChatScreen extends StatefulWidget {` and ending at the matching closing `}` right before the `// ─── Report a Problem Screen ───` comment).

Delete the entire `_ChatBubble` and `_ThinkingBubble` classes (the block starting at `class _ChatBubble extends StatelessWidget {` and ending at the matching closing `}` right before `class _AttachBtn extends StatelessWidget {`).

- [ ] **Step 6: Verify it compiles and all tests pass**

Run: `dart analyze lib/features/help_support/presentation/views/help_support_view.dart`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/help_support/presentation/views/help_support_view.dart
git commit -m "refactor(help-support): retire full-screen AI Assistant in favor of Dash"
```

---

### Task 8: Final verification pass

**Files:** none (verification only)

- [ ] **Step 1: Full static analysis**

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 3: Manual run-through**

Run the app (`flutter run`) and confirm, per the design spec's Testing section:
- The Dash bubble renders bottom-right on Home, Explore, Shop, and Profile tabs, and does not overlap the dialer's call button.
- The orange nudge dot is visible before first tapping the bubble, and gone afterward for the rest of the session.
- Tapping the bubble opens the sheet with the dimmed current tab visible underneath.
- Each of the four FAQ chips returns its expected reply.
- Typing a free-text question that matches a keyword (e.g. "what's my data balance") returns the same reply as the matching chip.
- Typing an unrelated question returns the generic fallback.
- Tapping "Talk to a human" opens WhatsApp (or the WhatsApp intent) with a pre-filled message.
- Help & Support → "Ask Dash" opens the same sheet (not a full-screen route).

- [ ] **Step 4: Report results to the user**

Summarize what was verified and flag anything that didn't match the spec before considering the feature done.
