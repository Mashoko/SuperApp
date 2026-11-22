import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Exchanges the user's stored Afri Com credentials for a backend app-user
/// JWT and keeps that token in SharedPreferences.
class BackendSessionService {
  BackendSessionService(this._prefs, {http.Client? client})
      : _client = client ?? http.Client();

  static const String _sessionUrl =
      'https://superapp-diht.onrender.com/api/app-auth/session';
  static const String _tokenKey = 'backend_app_token';

  final SharedPreferences _prefs;
  final http.Client _client;
  Future<String?>? _pendingRefresh;

  Future<String?> token() async => _prefs.getString(_tokenKey);

  /// Requests a new token. Concurrent callers share one in-flight request.
  /// Returns null on any failure (missing credentials, rejection, network).
  Future<String?> refresh() {
    return _pendingRefresh ??= _doRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<String?> _doRefresh() async {
    try {
      final username = _prefs.getString(AppConstants.keyAuthUser);
      final password = _prefs.getString(AppConstants.keyPassword);
      if (username == null ||
          username.isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }
      final displayName = _prefs.getString(AppConstants.keyDisplayName);
      final response = await _client.post(
        Uri.parse(_sessionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          if (displayName != null && displayName.isNotEmpty)
            'displayName': displayName,
        }),
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      final token = decoded is Map ? decoded['token'] : null;
      if (token is! String || token.isEmpty) return null;
      await _prefs.setString(_tokenKey, token);
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
  }
}
