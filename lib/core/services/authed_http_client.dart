import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_session_service.dart';

/// Adds the app-user bearer token to every request. With no stored token but
/// stored credentials it starts a session before the first attempt. On a 401
/// it refreshes the session once and retries once; refresh failure returns the
/// original 401. Other statuses (including 429) never trigger a refresh.
class AuthedHttpClient extends http.BaseClient {
  AuthedHttpClient(this._session, {http.Client? inner})
      : _inner = inner ?? http.Client();

  final BackendSessionService _session;
  final http.Client _inner;

  /// Called when a protected route answers 403 with code KYC_RESTRICTED.
  /// Set after construction. Never allowed to throw into the request.
  void Function()? onKycRestricted;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await _sendWithRefresh(request);
    if (res.statusCode != 403 || onKycRestricted == null) return res;
    return _checkKycRestricted(res);
  }

  Future<http.StreamedResponse> _checkKycRestricted(
      http.StreamedResponse res) async {
    try {
      final bytes = await res.stream.toBytes();
      try {
        final body = jsonDecode(utf8.decode(bytes, allowMalformed: true));
        if (body is Map && body['code'] == 'KYC_RESTRICTED') {
          onKycRestricted?.call();
        }
      } catch (_) {
        // Non-JSON, empty or wrong shape, or a throwing callback: ignore.
      }
      return http.StreamedResponse(
        http.ByteStream.fromBytes(bytes),
        res.statusCode,
        contentLength: bytes.length,
        request: res.request,
        headers: res.headers,
        isRedirect: res.isRedirect,
        persistentConnection: res.persistentConnection,
        reasonPhrase: res.reasonPhrase,
      );
    } catch (_) {
      return res;
    }
  }

  Future<http.StreamedResponse> _sendWithRefresh(
      http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    var usedToken = await _session.token();
    // Users upgrading while legacy mode is on never see a 401, so start the
    // session up front. Null (failure or cooldown) sends without a token.
    if (usedToken == null && _session.hasCredentials()) {
      usedToken = await _session.refresh();
    }

    final first = await _inner.send(_build(request, bytes, usedToken));
    if (first.statusCode != 401) return first;

    // If another request already replaced the token, reuse it rather than
    // asking the backend for yet another one.
    final current = await _session.token();
    final fresh = (current != null && current != usedToken)
        ? current
        : await _session.refresh();
    if (fresh == null) return first;

    await first.stream.drain<void>();
    return _inner.send(_build(request, bytes, fresh));
  }

  http.Request _build(
      http.BaseRequest original, List<int> bytes, String? token) {
    final req = http.Request(original.method, original.url)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..headers.addAll(original.headers)
      ..bodyBytes = bytes;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    return req;
  }

  @override
  void close() => _inner.close();
}
