import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Exchanges the user's stored Afri Com credentials for a backend app-user
/// JWT and keeps that token in SharedPreferences.
///
/// After a failed refresh no new network refresh is attempted until a
/// cooldown ends: the server's `Retry-After` on a 429, otherwise
/// [defaultCooldown]. A successful refresh or [clear] ends the cooldown.
class BackendSessionService {
  BackendSessionService(this._prefs,
      {http.Client? client, DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  static const String _sessionUrl =
      'https://superapp-diht.onrender.com/api/app-auth/session';
  static const String _tokenKey = 'backend_app_token';
  static const Duration defaultCooldown = Duration(seconds: 60);

  final SharedPreferences _prefs;
  final http.Client _client;
  final DateTime Function() _now;
  Future<String?>? _pendingRefresh;
  DateTime? _cooldownUntil;

  /// Bumped by [clear] so a refresh that started for the previous account
  /// cannot store its token afterwards.
  int _generation = 0;

  Future<String?> token() async => _prefs.getString(_tokenKey);

  /// Whether Afri Com credentials are stored, so a refresh could succeed.
  bool hasCredentials() {
    final username = _prefs.getString(AppConstants.keyAuthUser);
    final password = _prefs.getString(AppConstants.keyPassword);
    return username != null &&
        username.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  /// Requests a new token. Concurrent callers share one in-flight request.
  /// Returns null on any failure (missing credentials, rejection, network)
  /// and, without a network call, while a cooldown is active.
  Future<String?> refresh() {
    final until = _cooldownUntil;
    if (until != null && _now().isBefore(until)) return Future.value(null);
    final pending = _pendingRefresh;
    if (pending != null) return pending;
    late final Future<String?> started;
    started = _doRefresh(_generation).whenComplete(() {
      if (identical(_pendingRefresh, started)) _pendingRefresh = null;
    });
    return _pendingRefresh = started;
  }

  Future<String?> _doRefresh(int generation) async {
    try {
      if (!hasCredentials()) return null;
      final username = _prefs.getString(AppConstants.keyAuthUser)!;
      final password = _prefs.getString(AppConstants.keyPassword)!;
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
      if (response.statusCode != 200) {
        _startCooldown(generation, response);
        return null;
      }
      final decoded = jsonDecode(response.body);
      final token = decoded is Map ? decoded['token'] : null;
      if (token is! String || token.isEmpty) {
        _startCooldown(generation, null);
        return null;
      }
      if (generation != _generation) return null;
      _cooldownUntil = null;
      await _prefs.setString(_tokenKey, token);
      return token;
    } catch (_) {
      _startCooldown(generation, null);
      return null;
    }
  }

  void _startCooldown(int generation, http.Response? response) {
    if (generation != _generation) return;
    var wait = defaultCooldown;
    if (response?.statusCode == 429) {
      final seconds = int.tryParse(response!.headers['retry-after'] ?? '');
      if (seconds != null && seconds >= 0) wait = Duration(seconds: seconds);
    }
    _cooldownUntil = _now().add(wait);
  }

  /// Removes the stored token, ends any cooldown, and detaches any in-flight
  /// refresh so its result is discarded.
  Future<void> clear() async {
    _generation++;
    _cooldownUntil = null;
    _pendingRefresh = null;
    await _prefs.remove(_tokenKey);
  }
}
