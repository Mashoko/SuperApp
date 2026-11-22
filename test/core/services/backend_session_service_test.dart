import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mvvm_sip_demo/core/services/backend_session_service.dart';
import 'package:mvvm_sip_demo/core/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('BackendSessionService', () {
    test('token() returns stored token without network', () async {
      final prefs = await _prefs({'backend_app_token': 'abc'});
      var calls = 0;
      final service = BackendSessionService(prefs,
          client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }));
      expect(await service.token(), 'abc');
      expect(calls, 0);
    });

    test('refresh() posts stored credentials and stores token', () async {
      final prefs = await _prefs({
        AppConstants.keyAuthUser: '+263771234567',
        AppConstants.keyPassword: 'pw',
        AppConstants.keyDisplayName: 'Rose',
      });
      late http.Request seen;
      final service = BackendSessionService(prefs,
          client: MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'token': 'jwt1', 'user': {}}), 200,
            headers: {'content-type': 'application/json'});
      }));
      expect(await service.refresh(), 'jwt1');
      expect(seen.url.toString(),
          'https://superapp-diht.onrender.com/api/app-auth/session');
      expect(jsonDecode(seen.body), {
        'username': '+263771234567',
        'password': 'pw',
        'displayName': 'Rose',
      });
      expect(await service.token(), 'jwt1');
    });

    test('refresh() omits displayName when none stored', () async {
      final prefs = await _prefs({
        AppConstants.keyAuthUser: 'u',
        AppConstants.keyPassword: 'pw',
        AppConstants.keyDisplayName: '',
      });
      late Map body;
      final service = BackendSessionService(prefs,
          client: MockClient((req) async {
        body = jsonDecode(req.body) as Map;
        return http.Response(jsonEncode({'token': 't'}), 200);
      }));
      await service.refresh();
      expect(body.containsKey('displayName'), isFalse);
    });

    test('refresh() returns null on 401 and does not store', () async {
      final prefs = await _prefs({
        AppConstants.keyAuthUser: 'u',
        AppConstants.keyPassword: 'bad',
      });
      final service = BackendSessionService(prefs,
          client: MockClient((_) async => http.Response('{}', 401)));
      expect(await service.refresh(), isNull);
      expect(await service.token(), isNull);
    });

    test('refresh() returns null without credentials or on network error',
        () async {
      var calls = 0;
      final empty = BackendSessionService(await _prefs({}),
          client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }));
      expect(await empty.refresh(), isNull);
      expect(calls, 0);

      final prefs = await _prefs({
        AppConstants.keyAuthUser: 'u',
        AppConstants.keyPassword: 'pw',
      });
      final failing = BackendSessionService(prefs,
          client: MockClient((_) async => throw http.ClientException('down')));
      expect(await failing.refresh(), isNull);
    });

    test('clear() removes the token', () async {
      final prefs = await _prefs({'backend_app_token': 'abc'});
      final service = BackendSessionService(prefs,
          client: MockClient((_) async => http.Response('{}', 500)));
      await service.clear();
      expect(await service.token(), isNull);
    });
  });
}
