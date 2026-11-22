import 'package:http/http.dart' as http;

import 'backend_session_service.dart';

/// Adds the app-user bearer token to every request. On a 401 it refreshes the
/// session once and retries once; refresh failure returns the original 401.
class AuthedHttpClient extends http.BaseClient {
  AuthedHttpClient(this._session, {http.Client? inner})
      : _inner = inner ?? http.Client();

  final BackendSessionService _session;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final usedToken = await _session.token();

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
