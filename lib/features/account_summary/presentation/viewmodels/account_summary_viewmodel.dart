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

  Future<void> refresh(String username, {String? password}) async {
    if (username.isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.fetchAccountSummary(username, password: password);
    _loading = false;

    if (result == null) {
      _error = 'Failed to refresh account summary.';
    } else {
      _summary = result;
    }
    notifyListeners();
  }

  Future<void> loadCurrentUser() async {
    print('--- AccountSummaryViewModel: Loading current user... ---');
    _loading = true;
    notifyListeners();

    final creds = await _authService.getStoredCredentials();
    print('--- AccountSummaryViewModel: Credentials found: ${creds != null} ---');
    
    if (creds == null) {
      _loading = false;
      _error = 'No user logged in';
      print('--- AccountSummaryViewModel: No user logged in. ---');
      notifyListeners();
      return;
    }

    final username = creds['username'];
    final password = creds['password']; // Get password
    print('--- AccountSummaryViewModel: Username: $username ---');
    
    if (username != null) {
      await refresh(username, password: password);
    } else {
      _loading = false;
      _error = 'Invalid user credentials';
       print('--- AccountSummaryViewModel: Invalid credentials (username null). ---');
      notifyListeners();
    }
  }
}


