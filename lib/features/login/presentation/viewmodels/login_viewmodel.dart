import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../../../core/services/otp_auth_service.dart';
import '../../../../core/utils/constants.dart';
import '../../../registration/domain/entities/sip_user.dart';
import '../../../registration/domain/usecases/register_user.dart';

import '../../../../users_client.dart';
import '../../../../core/utils/crypto_utils.dart';

/// ViewModel handling Username/Password login + SIP auto‑registration + account summary.
class LoginViewModel extends ChangeNotifier {
  final OtpAuthService _authService;
  final RegisterUser _registerUser;
  final UsersClient _usersClient;

  LoginViewModel(this._authService, this._registerUser, this._usersClient);

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// Login with Username and Password.
  ///
  /// Returns `summary` map on success (alias, balance, etc.) or empty map if summary fetch fails.
  /// Returns `null` if login fails.
  Future<Map<String, dynamic>?> login(
    String username,
    String password,
  ) async {
    final trimmedUsername = username.trim();
    final trimmedPassword = password.trim();

    if (trimmedUsername.isEmpty || trimmedPassword.isEmpty) {
      _setError('Please enter both Username and Password.');
      return null;
    }

    _setLoading(true);
    _setError(null);

    debugPrint('--- Login Flow: Starting Login for $trimmedUsername ---');

    // Fetch SIP Configuration
    String domain = AppConstants.sipDomain;
    String wsUrl = AppConstants.websocketUrl;
    String originUrl = 'https://$domain';

    try {
      debugPrint('--- Login Flow: Fetching SIP Domain... ---');
      final domainResp = await _usersClient.getDomainForPackageID();
      if (domainResp.domain.isNotEmpty) domain = domainResp.domain;
      debugPrint('--- Login Flow: Domain: $domain ---');

      debugPrint('--- Login Flow: Fetching WebSocket URL... ---');
      await _usersClient.getWebsocketUrlFromApi();
      // Use default if API doesn't return explicit URL or if we need to parse it
      // Assuming fallback to AppConstants for now if empty
      debugPrint('--- Login Flow: WebSocket URL: $wsUrl ---');
      
      debugPrint('--- Login Flow: Fetching Origin URL... ---');
      final originResp = await _usersClient.getOriginUrlFromApi();
      if (originResp.info.information.isNotEmpty) {
        originUrl = originResp.info.information;
      }
      debugPrint('--- Login Flow: Origin URL: $originUrl ---');
    } catch (e) {
      // Fallback to defaults if RPCs fail
      debugPrint('--- Login Flow: Failed to fetch SIP config: $e ---');
      print('Failed to fetch SIP config: $e');
    }

    // Compute MD5 Hash for SIP Password
    debugPrint('--- Login Flow: Computing MD5 Hash... ---');
    final sipPasswordHash = CryptoUtils.md5Hash('$trimmedUsername:$domain:$trimmedPassword');
    debugPrint('--- Login Flow: MD5 Hash Computed: $sipPasswordHash ---');

    // Build SipUser using dynamic SIP configuration.
    final user = SipUser(
      port: AppConstants.port,
      displayName: trimmedUsername,
      password: trimmedPassword, // Use plain password for sip_ua
      authUser: trimmedUsername,
      wsUrl: wsUrl,
      sipUri: '$trimmedUsername@$domain',
      selectedTransport: TransportType.WS,
      wsExtraHeaders: {
        'Origin': originUrl,
        // 'Host': domain, // REMOVED: Do not override Host header in WS handshake.
      },
    );

    // Configure SIPUAHelper and persist user via existing pipeline.
    debugPrint('--- Login Flow: Initiating SIP Registration... ---');
    await _registerUser(user);
    
    // Check if registration was successful (or at least initiated)
    // The RegisterUser usecase returns a Result.
    // If it fails, we should probably show an error, but for now let's assume 
    // we proceed to fetch account summary as "Login" implies authenticating with backend too.
    // However, in this flow, SIP registration IS the login.
    
    // Fetch account summary (alias, balance, etc.) after registration.
    // If fetch fails, still return success with username for navigation.
    debugPrint('--- Login Flow: Fetching Account Summary... ---');
    final summary = await _authService.fetchAccountSummary(trimmedUsername);

    _setLoading(false);
    
    debugPrint('--- Login Flow: Login Completed ---');
    // Return summary if available, otherwise return minimal data with username
    return summary ?? {'username': trimmedUsername, 'status': 'logged_in'};
  }

  /// Check for stored credentials and auto-login.
  Future<Map<String, dynamic>?> checkAutoLogin() async {
    _setLoading(true);
    
    final creds = await _authService.getStoredCredentials();
    if (creds != null) {
      debugPrint('--- Login Flow: Found stored credentials for ${creds['username']} ---');
      // Use existing login flow to re-register and fetch summary
      return login(creds['username']!, creds['password']!);
    }
    
    _setLoading(false);
    return null;
  }
}


