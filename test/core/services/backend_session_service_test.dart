import 'dart:async';
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
        AppConstants.keyAuthUser: '+263770000000',
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
        'username': '+263770000000',
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

    group('cooldown after a failed refresh', () {
      late DateTime now;
      late int calls;
      late http.Response Function() reply;
      late BackendSessionService service;

      setUp(() async {
        now = DateTime(2026, 11, 22, 12);
        calls = 0;
        reply = () => http.Response('{}', 503);
        final prefs = await _prefs({
          AppConstants.keyAuthUser: 'u',
          AppConstants.keyPassword: 'pw',
        });
        service = BackendSessionService(prefs,
            now: () => now, client: MockClient((_) async {
          calls++;
          return reply();
        }));
      });

      test('no network refresh within 60 s, one after', () async {
        expect(await service.refresh(), isNull);
        expect(calls, 1);
        now = now.add(const Duration(seconds: 59));
        expect(await service.refresh(), isNull);
        expect(calls, 1);
        now = now.add(const Duration(seconds: 2));
        reply = () => http.Response(jsonEncode({'token': 'jwt1'}), 200);
        expect(await service.refresh(), 'jwt1');
        expect(calls, 2);
      });

      test('network error also starts the cooldown', () async {
        reply = () => throw http.ClientException('down');
        expect(await service.refresh(), isNull);
        expect(await service.refresh(), isNull);
        expect(calls, 1);
      });

      test('honours Retry-After seconds on a 429', () async {
        reply = () =>
            http.Response('{}', 429, headers: {'retry-after': '120'});
        expect(await service.refresh(), isNull);
        now = now.add(const Duration(seconds: 61));
        expect(await service.refresh(), isNull);
        expect(calls, 1);
        now = now.add(const Duration(seconds: 60));
        expect(await service.refresh(), isNull);
        expect(calls, 2);
      });

      test('successful refresh resets the cooldown', () async {
        expect(await service.refresh(), isNull);
        now = now.add(const Duration(seconds: 61));
        reply = () => http.Response(jsonEncode({'token': 'jwt1'}), 200);
        expect(await service.refresh(), 'jwt1');
        // A later failure starts a fresh 60 s cooldown from that failure.
        reply = () => http.Response('{}', 503);
        expect(await service.refresh(), isNull);
        expect(calls, 3);
        now = now.add(const Duration(seconds: 30));
        expect(await service.refresh(), isNull);
        expect(calls, 3);
      });

      test('clear() ends the cooldown', () async {
        expect(await service.refresh(), isNull);
        await service.clear();
        reply = () => http.Response(jsonEncode({'token': 'jwt1'}), 200);
        expect(await service.refresh(), 'jwt1');
        expect(calls, 2);
      });
    });

    test('a refresh started before clear() does not store its token',
        () async {
      final prefs = await _prefs({
        AppConstants.keyAuthUser: 'old-user',
        AppConstants.keyPassword: 'pw',
      });
      final gate = Completer<void>();
      var calls = 0;
      final service =
          BackendSessionService(prefs, client: MockClient((_) async {
        calls++;
        if (calls == 1) await gate.future;
        return http.Response(jsonEncode({'token': 'jwt$calls'}), 200);
      }));
      final stale = service.refresh();
      await Future<void>.delayed(Duration.zero);
      await service.clear();
      // The next account's refresh does not join the stale request.
      expect(await service.refresh(), 'jwt2');
      gate.complete();
      expect(await stale, isNull);
      expect(await service.token(), 'jwt2');
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
