import 'package:flutter/foundation.dart';

import '../../../faq/presentation/viewmodels/faq_viewmodel.dart';

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
  DashViewModel(this._faqViewModel);

  final FaqViewModel _faqViewModel;

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

    for (final cat in _faqViewModel.categories) {
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
