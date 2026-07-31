/// Retries and coalesces balance refreshes triggered by a call ending.
///
/// Depends only on simple function-shaped callbacks rather than concrete
/// ViewModels, so it has no Flutter/network dependencies of its own and is
/// fully unit-testable. The two balance-fetch callbacks are expected to
/// return `true` on success and `false` on failure, and to already
/// preserve their own last-known value on failure (see `resolveOnFetch`
/// in `lib/core/utils/balance_resolution.dart`) — this coordinator only
/// decides *when* to call them and *when* to notify the user, never what
/// value to display.
class BalanceRefreshCoordinator {
  BalanceRefreshCoordinator({
    required Future<bool> Function() refreshAccountSummary,
    required Future<bool> Function() refreshDialpad,
    required void Function() showRetryingNotice,
  })  : _refreshAccountSummary = refreshAccountSummary,
        _refreshDialpad = refreshDialpad,
        _showRetryingNotice = showRetryingNotice;

  final Future<bool> Function() _refreshAccountSummary;
  final Future<bool> Function() _refreshDialpad;
  final void Function() _showRetryingNotice;

  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  bool _refreshing = false;

  /// Whether a refresh sequence is currently in flight. A second call to
  /// [refreshAfterCall] while this is true is a no-op.
  bool get isRefreshing => _refreshing;

  /// Refreshes both balance sources, retrying only whichever one(s)
  /// failed, per the 2s/5s/10s backoff schedule. No-ops if a refresh is
  /// already in flight (guards against overlapping triggers, e.g.
  /// call-waiting ending two calls in quick succession).
  Future<void> refreshAfterCall() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      var results = await Future.wait([
        _refreshAccountSummary(),
        _refreshDialpad(),
      ]);
      var accountDone = results[0];
      var dialpadDone = results[1];

      if (accountDone && dialpadDone) return;

      _showRetryingNotice();

      for (final delay in _retryDelays) {
        await Future<void>.delayed(delay);
        results = await Future.wait([
          _attempt(_refreshAccountSummary, accountDone),
          _attempt(_refreshDialpad, dialpadDone),
        ]);
        accountDone = results[0];
        dialpadDone = results[1];
        if (accountDone && dialpadDone) return;
      }
      // All attempts exhausted — give up silently. Both callbacks already
      // preserved their last-known values, so there is nothing further to do.
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> _attempt(Future<bool> Function() fetch, bool alreadyDone) {
    return alreadyDone ? Future.value(true) : fetch();
  }
}
