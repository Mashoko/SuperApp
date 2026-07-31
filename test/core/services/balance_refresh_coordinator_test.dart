import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/services/balance_refresh_coordinator.dart';

void main() {
  group('BalanceRefreshCoordinator', () {
    test('both succeed on the first attempt: no retry, no notice', () {
      fakeAsync((async) {
        var accountCalls = 0;
        var dialpadCalls = 0;
        var noticeShown = 0;

        final coordinator = BalanceRefreshCoordinator(
          refreshAccountSummary: () async {
            accountCalls++;
            return true;
          },
          refreshDialpad: () async {
            dialpadCalls++;
            return true;
          },
          showRetryingNotice: () => noticeShown++,
        );

        coordinator.refreshAfterCall();
        async.flushMicrotasks();

        expect(accountCalls, 1);
        expect(dialpadCalls, 1);
        expect(noticeShown, 0);
        expect(coordinator.isRefreshing, isFalse);
      });
    });

    test('account fails then succeeds on the first retry: one notice, no unnecessary dialpad retry', () {
      fakeAsync((async) {
        var accountCalls = 0;
        var dialpadCalls = 0;
        var noticeShown = 0;

        final coordinator = BalanceRefreshCoordinator(
          refreshAccountSummary: () async {
            accountCalls++;
            return accountCalls > 1; // fails first time, succeeds on retry
          },
          refreshDialpad: () async {
            dialpadCalls++;
            return true;
          },
          showRetryingNotice: () => noticeShown++,
        );

        coordinator.refreshAfterCall();
        async.elapse(const Duration(seconds: 20));

        expect(accountCalls, 2);
        expect(dialpadCalls, 1);
        expect(noticeShown, 1);
        expect(coordinator.isRefreshing, isFalse);
      });
    });

    test('all attempts fail: notice shown exactly once, gives up silently after 4 total tries', () {
      fakeAsync((async) {
        var accountCalls = 0;
        var dialpadCalls = 0;
        var noticeShown = 0;

        final coordinator = BalanceRefreshCoordinator(
          refreshAccountSummary: () async {
            accountCalls++;
            return false;
          },
          refreshDialpad: () async {
            dialpadCalls++;
            return false;
          },
          showRetryingNotice: () => noticeShown++,
        );

        coordinator.refreshAfterCall();
        async.elapse(const Duration(seconds: 20));

        expect(accountCalls, 4); // 1 initial + 3 retries
        expect(dialpadCalls, 4);
        expect(noticeShown, 1);
        expect(coordinator.isRefreshing, isFalse);
      });
    });

    test('a second trigger while a refresh is in flight is a no-op', () {
      fakeAsync((async) {
        var accountCalls = 0;

        final coordinator = BalanceRefreshCoordinator(
          refreshAccountSummary: () async {
            accountCalls++;
            await Future<void>.delayed(const Duration(seconds: 1));
            return true;
          },
          refreshDialpad: () async => true,
          showRetryingNotice: () {},
        );

        coordinator.refreshAfterCall();
        coordinator.refreshAfterCall();
        async.elapse(const Duration(seconds: 2));

        expect(accountCalls, 1);
      });
    });
  });
}
