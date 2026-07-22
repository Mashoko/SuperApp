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
