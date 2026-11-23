import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mvvm_sip_demo/core/services/authed_http_client.dart';
import 'package:mvvm_sip_demo/core/services/backend_session_service.dart';
import 'package:mvvm_sip_demo/core/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Harness {
  _Harness(this.session, this.client, this.log);
  final BackendSessionService session;
  final AuthedHttpClient client;
  final List<http.BaseRequest> log;
  int get sessionCalls =>
      log.where((r) => r.url.path.endsWith('/app-auth/session')).length;
}

/// [api] answers non-session calls; session calls return a token that
/// increments (jwt1, jwt2, ...) unless [sessionStatus] is not 200.
Future<_Harness> _build(
  Future<http.Response> Function(http.Request req, int apiCall) api, {
  int sessionStatus = 200,
  String? storedToken,
}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyAuthUser: 'u',
    AppConstants.keyPassword: 'pw',
    if (storedToken != null) 'backend_app_token': storedToken,
  });
  final prefs = await SharedPreferences.getInstance();
  final log = <http.BaseRequest>[];
  var apiCalls = 0;
  var tokens = 0;
  final mock = MockClient((req) async {
    log.add(req);
    if (req.url.path.endsWith('/app-auth/session')) {
      if (sessionStatus != 200) return http.Response('{}', sessionStatus);
      tokens++;
      return http.Response(jsonEncode({'token': 'jwt$tokens'}), 200);
    }
    apiCalls++;
    return api(req, apiCalls);
  });
  final session = BackendSessionService(prefs, client: mock);
  return _Harness(session, AuthedHttpClient(session, inner: mock), log);
}

void main() {
  test('adds bearer header', () async {
    final h = await _build((req, _) async => http.Response('ok', 200),
        storedToken: 'tok');
    final res = await h.client.get(Uri.parse('https://x.test/api/cart'));
    expect(res.statusCode, 200);
    expect(h.log.single.headers['Authorization'], 'Bearer tok');
  });

  test('no stored token: starts a session before the first request',
      () async {
    final h = await _build((req, _) async => http.Response('ok', 200));
    final res = await h.client.get(Uri.parse('https://x.test/api/cart'));
    expect(res.statusCode, 200);
    expect(h.log.length, 2);
    expect(h.log[0].url.path, endsWith('/app-auth/session'));
    expect(h.log[1].url.path, '/api/cart');
    expect(h.log[1].headers['Authorization'], 'Bearer jwt1');
  });

  test('no stored token and refresh fails: sends without a token', () async {
    final h = await _build((req, _) async => http.Response('ok', 200),
        sessionStatus: 503);
    final res = await h.client.get(Uri.parse('https://x.test/api/cart'));
    expect(res.statusCode, 200);
    expect(h.sessionCalls, 1);
    expect(h.log.last.headers.containsKey('Authorization'), isFalse);

    // Within the cooldown the next request makes no session call.
    await h.client.get(Uri.parse('https://x.test/api/cart'));
    expect(h.sessionCalls, 1);
  });

  test('a 429 on a user route does not refresh', () async {
    final h = await _build((req, _) async => http.Response('slow down', 429),
        storedToken: 'tok');
    final res = await h.client.get(Uri.parse('https://x.test/api/cart'));
    expect(res.statusCode, 429);
    expect(h.sessionCalls, 0);
    expect(h.log.length, 1);
  });

  test('refreshes once on 401 then retries once', () async {
    final h = await _build(
        (req, n) async => http.Response('', n == 1 ? 401 : 200),
        storedToken: 'old');
    final res = await h.client
        .post(Uri.parse('https://x.test/api/cart'), body: 'payload');
    expect(res.statusCode, 200);
    expect(h.log.length, 3);
    expect(h.sessionCalls, 1);
    expect(h.log.last.headers['Authorization'], 'Bearer jwt1');
    expect((h.log.last as http.Request).body, 'payload');
  });

  test('does not loop when retry also 401', () async {
    final h = await _build((req, _) async => http.Response('', 401),
        storedToken: 'old');
    final res = await h.client.get(Uri.parse('https://x.test/api/cart'));
    expect(res.statusCode, 401);
    expect(h.log.length, 3);
  });

  test('returns original 401 when refresh fails', () async {
    final h = await _build((req, _) async => http.Response('nope', 401),
        sessionStatus: 503, storedToken: 'old');
    final res = await h.client.get(Uri.parse('https://x.test/api/cart'));
    expect(res.statusCode, 401);
    expect(res.body, 'nope');
    expect(h.log.length, 2);
  });

  test('concurrent 401s share a single session refresh', () async {
    final gate = Completer<void>();
    final h = await _build((req, n) async {
      if (req.headers['Authorization'] == 'Bearer old') {
        await gate.future;
        return http.Response('', 401);
      }
      return http.Response('ok', 200);
    }, storedToken: 'old');
    final a = h.client.get(Uri.parse('https://x.test/api/a'));
    final b = h.client.get(Uri.parse('https://x.test/api/b'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    final results = await Future.wait([a, b]);
    expect(results.map((r) => r.statusCode), [200, 200]);
    expect(h.sessionCalls, 1);
  });

  test('replays multipart bodies on retry', () async {
    final bodies = <String>[];
    final h = await _build((req, n) async {
      bodies.add(req.body);
      return http.Response('', n == 1 ? 401 : 200);
    }, storedToken: 'old');
    final req =
        http.MultipartRequest('POST', Uri.parse('https://x.test/api/posts'))
          ..fields['caption'] = 'hi';
    final res = await http.Response.fromStream(await h.client.send(req));
    expect(res.statusCode, 200);
    expect(bodies.length, 2);
    expect(bodies[1], contains('caption'));
  });

  group('onKycRestricted', () {
    const restricted =
        '{"code":"KYC_RESTRICTED","message":"Complete your KYC verification."}';

    test('fires once for a 403 KYC_RESTRICTED body and keeps the body',
        () async {
      final h = await _build((req, _) async => http.Response(restricted, 403),
          storedToken: 'tok');
      var calls = 0;
      h.client.onKycRestricted = () => calls++;
      final res = await h.client.get(Uri.parse('https://x.test/api/cart'));
      expect(res.statusCode, 403);
      expect(res.body, restricted);
      expect(calls, 1);
    });

    test('not fired for other 403s, non-JSON, empty or wrong shapes',
        () async {
      for (final body in [
        '{"code":"OTHER"}',
        'not json',
        '',
        '[1,2]',
        '"KYC_RESTRICTED"',
      ]) {
        final h = await _build((req, _) async => http.Response(body, 403),
            storedToken: 'tok');
        var calls = 0;
        h.client.onKycRestricted = () => calls++;
        final res = await h.client.get(Uri.parse('https://x.test/api/cart'));
        expect(res.statusCode, 403);
        expect(calls, 0, reason: body);
      }
    });

    test('not fired for non-403, and a throwing callback is swallowed',
        () async {
      final h = await _build((req, _) async => http.Response(restricted, 400),
          storedToken: 'tok');
      var calls = 0;
      h.client.onKycRestricted = () => calls++;
      await h.client.get(Uri.parse('https://x.test/api/cart'));
      expect(calls, 0);

      final h2 = await _build((req, _) async => http.Response(restricted, 403),
          storedToken: 'tok');
      h2.client.onKycRestricted = () => throw StateError('boom');
      final res = await h2.client.get(Uri.parse('https://x.test/api/cart'));
      expect(res.statusCode, 403);
    });
  });
}
