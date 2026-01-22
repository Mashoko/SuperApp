import 'package:flutter/foundation.dart';

import '../../../../core/services/otp_auth_service.dart';

/// ViewModel for fetching and holding the current account summary
/// (alias, balance, domain, status) for the logged-in SIP user.
class AccountSummaryViewModel extends ChangeNotifier {
  final OtpAuthService _authService;

  AccountSummaryViewModel(this._authService);

  Map<String, dynamic>? _summary;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;

  String? get alias => _summary?['alias'] as String?;

  double? get balance {
    final b = _summary?['balance'];
    if (b is double) return b;
    if (b is num) return b.toDouble();
    return null;
  }

  Future<void> refresh(String username) async {
    if (username.isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.fetchAccountSummary(username);
    _loading = false;

    if (result == null) {
      _error = 'Failed to refresh account summary.';
    } else {
      _summary = result;
    }
    notifyListeners();
  }

  Future<void> loadCurrentUser() async {
    _loading = true;
    notifyListeners();

    final creds = await _authService.getStoredCredentials();
    if (creds == null) {
      _loading = false;
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    final username = creds['username'];
    if (username != null) {
      await refresh(username);
    } else {
      _loading = false;
      _error = 'Invalid user credentials';
      notifyListeners();
    }
  }
}


