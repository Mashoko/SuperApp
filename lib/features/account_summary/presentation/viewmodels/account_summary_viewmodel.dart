import 'package:flutter/foundation.dart';
import '../../../../core/services/otp_auth_service.dart';
import '../../../../core/utils/balance_resolution.dart';
import '../../../../payments_client.dart';

/// Fetches and holds the account summary for the logged-in SIP user.
///
/// Two independent gRPC calls run in parallel:
///  • users.proto  AccountBalance → alias, status, voice minutes (nanoseconds)
///  • payments.proto DealerAccountBalances → RTGS/money balance (dollars)
class AccountSummaryViewModel extends ChangeNotifier {
  final OtpAuthService _authService;
  final PaymentsClient _paymentsClient;

  AccountSummaryViewModel(this._authService, this._paymentsClient);

  Map<String, dynamic>? _summary;
  bool _loading = false;
  String? _error;

  /// Balance returned by the payments service (RTGS dollars). null = not yet loaded.
  double? _paymentsBalance;

  /// Whether the payments-balance fetch is still in flight.
  bool _paymentsLoading = false;

  Map<String, dynamic>? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;
  bool get paymentsLoading => _paymentsLoading;

  // ── Derived fields from users.proto response ───────────────────────────────

  String? get alias => _summary?['alias'] as String?;
  String? get username => _summary?['username'] as String?;
  dynamic get status => _summary?['status'];

  /// Raw balance from users.proto (nanoseconds — used for voice minutes only).
  double? get voiceBalanceNano {
    final b = _summary?['balance'];
    if (b is double) return b;
    if (b is num) return b.toDouble();
    return null;
  }

  /// Alias kept for backward compatibility with home_view, profile_view, dialer_view.
  double? get balance => voiceBalanceNano;

  /// Voice/airtime balance formatted as "X hrs Y mins" from nanoseconds.
  String get formattedMinutes {
    final b = voiceBalanceNano;
    if (b == null || b <= 0) return '0 min';
    final d = Duration(microseconds: (b / 1000).round());
    if (d.inHours >= 1) {
      return '${d.inHours} hr${d.inHours > 1 ? 's' : ''} '
          '${d.inMinutes.remainder(60)} min';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes} min${d.inMinutes > 1 ? 's' : ''}';
    }
    return '${d.inSeconds} sec';
  }

  // ── RTGS balance from payments.proto DealerAccountBalances ────────────────

  /// RTGS/money balance in dollars. null while loading or on error.
  double? get paymentsBalance => _paymentsBalance;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadCurrentUser() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final creds = await _authService.getStoredCredentials();
    if (creds == null) {
      _loading = false;
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    final username = creds['username'];
    final password = creds['password'];
    if (username == null) {
      _loading = false;
      _error = 'Invalid credentials';
      notifyListeners();
      return;
    }

    // Fire both gRPC calls in parallel.
    await Future.wait([
      _fetchUserSummary(username, password: password),
      _fetchPaymentsBalance(username, password: password ?? ''),
    ]);

    _loading = false;
    notifyListeners();
  }

  /// Returns `true` if the summary was fetched successfully. On failure the
  /// previously loaded summary (and its derived voice-minutes) is kept as-is.
  /// When [silent] is true, no `_error` is set on failure — used for
  /// background refreshes that must not surface a full-screen error state.
  Future<bool> _fetchUserSummary(String username,
      {String? password, bool silent = false}) async {
    final result =
        await _authService.fetchAccountSummary(username, password: password);
    if (result == null) {
      if (!silent) _error = 'Failed to load account details.';
      return false;
    }
    _summary = result;
    return true;
  }

  /// When [silent] is true, this is a background refresh: `_paymentsLoading`
  /// is never toggled, so the UI doesn't flash a loading state over an
  /// already-known balance while this runs.
  Future<bool> _fetchPaymentsBalance(String username,
      {required String password, bool silent = false}) async {
    if (!silent) {
      _paymentsLoading = true;
      notifyListeners();
    }
    var ok = false;
    try {
      final resp = await _paymentsClient.dealerAccountBalances(
        username: username,
        password: password,
      );

      ok = resp.status == Status.SUCCESSFUL || resp.status == Status.INFORMATION;
      _paymentsBalance = resolveOnFetch(
        previous: _paymentsBalance,
        ok: ok,
        onSuccess: resp.balance,
      );

      debugPrint('[Balance] status=${resp.status}  balance=${resp.balance}');
    } catch (e) {
      debugPrint('[Balance] error: $e');
    } finally {
      if (!silent) {
        _paymentsLoading = false;
        notifyListeners();
      }
    }
    return ok;
  }

  /// Background refresh of both the RTGS balance and voice-minute summary,
  /// without disturbing `loading`/`error`/`paymentsLoading` — used after a
  /// call ends so the UI updates in place instead of flashing a loading
  /// state over an already-known balance. Returns `true` only if both
  /// fetches succeeded; on any failure the previous values are kept.
  Future<bool> fetchBalance() async {
    final creds = await _authService.getStoredCredentials();
    if (creds == null) return false;
    final username = creds['username'];
    final password = creds['password'] ?? '';
    if (username == null) return false;
    final results = await Future.wait([
      _fetchUserSummary(username, password: password, silent: true),
      _fetchPaymentsBalance(username, password: password, silent: true),
    ]);
    notifyListeners();
    return results[0] && results[1];
  }

  /// Add [minutes] voice minutes to the logged-in account via RechargeAccount.
  /// Returns the server reply so callers can show success/error UI.
  Future<reply> rechargeMinutes(double minutes) async {
    final creds = await _authService.getStoredCredentials();
    if (creds == null) {
      return reply()..status = Status.ERROR;
    }
    final resp = await _paymentsClient.addMinutes(
      username: creds['username']!,
      password: creds['password'] ?? '',
      minutes: minutes,
    );
    // Refresh the voice balance so the UI reflects the new total.
    if (resp.status == Status.SUCCESSFUL || resp.status == Status.INFORMATION) {
      await _fetchUserSummary(creds['username']!, password: creds['password']);
      notifyListeners();
    }
    return resp;
  }

  /// Pull-to-refresh: reloads everything.
  Future<void> refresh() => loadCurrentUser();
}
