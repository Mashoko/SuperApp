import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_service.dart';

const _doc = {
  'id': 'aaaaaaaaaaaaaaaaaaaaaaaa',
  'kind': 'id_front',
  'mime': 'image/jpeg',
  'size': 1234,
  'createdAt': '2026-11-01T10:00:00.000Z',
};

const _me = {
  'status': 'IN_PROGRESS',
  'underlyingStatus': 'IN_PROGRESS',
  'launched': true,
  'deadline': '2026-12-31T00:00:00.000Z',
  'exemptUntil': null,
  'progress': 40,
  'outstanding': ['address.line1', 'documents.id_front'],
  'draft': {
    'personal': {'firstName': 'Tendai', 'dateOfBirth': '1990-05-04'},
    'address': {'city': 'Harare'},
    'identification': {
      'idType': 'national_id',
      'idExpiry': '2030-01-01',
      'idNumberMasked': '******1A23',
    },
    'updatedAt': '2026-11-01T10:00:00.000Z',
  },
  'documents': [_doc],
  'history': [
    {
      'version': 1,
      'submittedAt': '2026-10-01T10:00:00.000Z',
      'decision': 'rejected',
      'decidedAt': '2026-10-02T10:00:00.000Z',
      'reason': 'Photo is blurry.',
    }
  ],
  'rejectionReason': 'Photo is blurry.',
  'correctionNotes': null,
  'phone': '263771234567',
};

KycService _svc(Future<http.Response> Function(http.Request) h) =>
    KycService(client: MockClient(h));

http.Response _json(Object body, [int code = 200]) => http.Response(
    jsonEncode(body), code,
    headers: {'content-type': 'application/json'});

void main() {
  test('getStatus parses a full /me payload', () async {
    late http.Request seen;
    final s = await _svc((r) async {
      seen = r;
      return _json(_me);
    }).getStatus();
    expect(seen.url.path, '/api/kyc/me');
    expect(s.launched, isTrue);
    expect(s.status, 'IN_PROGRESS');
    expect(s.deadline, DateTime.utc(2026, 12, 31));
    expect(s.exemptUntil, isNull);
    expect(s.progress, 40);
    expect(s.outstanding, ['address.line1', 'documents.id_front']);
    expect(s.draft.personal.firstName, 'Tendai');
    expect(s.draft.personal.dateOfBirth, DateTime.utc(1990, 5, 4));
    expect(s.draft.address.city, 'Harare');
    expect(s.draft.identification.idType, 'national_id');
    expect(s.draft.identification.idNumberMasked, '******1A23');
    expect(s.documents.single.kind, 'id_front');
    expect(s.documents.single.size, 1234);
    expect(s.history.single.decision, 'rejected');
    expect(s.history.single.reason, 'Photo is blurry.');
    expect(s.rejectionReason, 'Photo is blurry.');
    expect(s.phone, '263771234567');
    expect(s.canEdit, isTrue);
    expect(s.isRestricted, isFalse);
  });

  test('null draft parses to an empty draft', () async {
    final s =
        await _svc((r) async => _json({..._me, 'draft': null})).getStatus();
    expect(s.draft.personal.firstName, isNull);
  });

  test('status helpers', () {
    KycStatus of(String st, {String? under}) => KycStatus.fromJson(
        {..._me, 'status': st, 'underlyingStatus': under ?? st});
    expect(of('RESTRICTED', under: 'EXPIRED').isRestricted, isTrue);
    expect(of('RESTRICTED', under: 'EXPIRED').canEdit, isTrue);
    expect(of('APPROVED').isVerified, isTrue);
    expect(of('APPROVED').canEdit, isFalse);
    expect(of('PENDING_REVIEW').isPendingReview, isTrue);
    expect(of('PENDING_REVIEW').canEdit, isFalse);
  });

  test('saveDraft sends idNumber only when newly typed, omits nulls',
      () async {
    final bodies = <Map<String, dynamic>>[];
    final svc = _svc((r) async {
      expect(r.method, 'PUT');
      expect(r.url.path, '/api/kyc/draft');
      bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
      return _json({'status': 'IN_PROGRESS', 'draft': null});
    });
    await svc.saveDraft(KycDraft(
      personal: KycPersonal(
          firstName: 'Tendai', dateOfBirth: DateTime.utc(1990, 5, 4)),
      identification:
          KycIdentification(idType: 'national_id', idNumberMasked: '******1A23'),
    ));
    await svc.saveDraft(KycDraft(
      identification: KycIdentification(
          idType: 'national_id',
          idNumberMasked: '******1A23',
          newIdNumber: '63-123456A12'),
    ));
    final first = bodies[0]['data'] as Map<String, dynamic>;
    expect(first['personal'],
        {'firstName': 'Tendai', 'dateOfBirth': '1990-05-04'});
    expect(first['identification'], {'idType': 'national_id'});
    expect(first.containsKey('address'), isFalse);
    expect(jsonEncode(first).contains('idNumber'), isFalse);
    expect((bodies[1]['data'] as Map)['identification'],
        {'idType': 'national_id', 'idNumber': '63-123456A12'});
  });

  test('uploadDocument sends multipart with kind and filename', () async {
    late http.Request seen;
    final progress = <double>[];
    final doc = await _svc((r) async {
      seen = r;
      return _json(_doc, 201);
    }).uploadDocument(
      kind: 'id_front',
      bytes: [1, 2, 3],
      filename: 'front.jpg',
      onProgress: progress.add,
    );
    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/kyc/documents');
    expect(seen.headers['content-type'], startsWith('multipart/form-data'));
    expect(seen.body, contains('name="kind"'));
    expect(seen.body, contains('id_front'));
    expect(seen.body, contains('name="file"'));
    expect(seen.body, contains('filename="front.jpg"'));
    expect(doc.id, 'aaaaaaaaaaaaaaaaaaaaaaaa');
    expect(progress, [0.0, 1.0]);
  });

  test('fetchDocument returns bytes and deleteDocument accepts 204', () async {
    final reqs = <http.Request>[];
    final svc = _svc((r) async {
      reqs.add(r);
      return r.method == 'GET'
          ? http.Response.bytes([9, 8, 7], 200)
          : http.Response('', 204);
    });
    expect(await svc.fetchDocument('abc'), [9, 8, 7]);
    await svc.deleteDocument('abc');
    expect(reqs[0].url.path, '/api/kyc/documents/abc');
    expect(reqs[1].method, 'DELETE');
  });

  test('submit 201 succeeds; 400 with errors throws KycValidationException',
      () async {
    await _svc((r) async => _json({'status': 'PENDING_REVIEW'}, 201)).submit();
    final svc = _svc((r) async => _json({
          'message': 'Some details are missing or invalid.',
          'errors': {'personal.firstName': 'Enter your first name.'}
        }, 400));
    try {
      await svc.submit();
      fail('should throw');
    } on KycValidationException catch (e) {
      expect(e.errors['personal.firstName'], 'Enter your first name.');
      expect(e.statusCode, 400);
    }
  });

  group('error mapping', () {
    Future<KycApiException> failure(int code, [Object? body]) async {
      final svc = _svc((r) async =>
          body == null ? http.Response('', code) : _json(body, code));
      try {
        await svc.getStatus();
      } on KycApiException catch (e) {
        return e;
      }
      throw StateError('no throw');
    }

    test('fixed messages', () async {
      expect((await failure(413, {'message': 'File is too large.'})).message,
          'This file is too large. Use a file under 8 MB.');
      expect((await failure(415, {'message': 'x'})).message,
          'Upload a JPEG, PNG or PDF file.');
      expect((await failure(429)).message,
          'Too many attempts. Please wait a few minutes.');
      expect(
          (await failure(503, {'message': 'KYC is temporarily unavailable.'}))
              .message,
          'Verification is temporarily unavailable. Please try again later.');
    });

    test('server message used otherwise, with fallback', () async {
      final e =
          await failure(409, {'message': 'Your KYC is already submitted.'});
      expect(e.message, 'Your KYC is already submitted.');
      expect(e.statusCode, 409);
      expect((await failure(500)).message,
          'Something went wrong. Please try again.');
    });

    test('network error', () async {
      final svc = _svc((r) async => throw http.ClientException('down'));
      expect(
          () => svc.getStatus(),
          throwsA(isA<KycApiException>().having((e) => e.message, 'message',
              'No connection. Check your internet and try again.')));
    });
  });

  test('notifications parse and markRead', () async {
    final reqs = <http.Request>[];
    final svc = _svc((r) async {
      reqs.add(r);
      if (r.method == 'POST') {
        return _json({
          'id': 'n1',
          'kind': 'SUBMITTED',
          'title': 'T',
          'body': 'B',
          'createdAt': '2026-11-01T10:00:00.000Z',
          'readAt': '2026-11-02T10:00:00.000Z',
        });
      }
      return _json({
        'items': [
          {
            'id': 'n1',
            'kind': 'SUBMITTED',
            'title': 'Received',
            'body': 'We got it.',
            'createdAt': '2026-11-01T10:00:00.000Z',
            'readAt': null,
          }
        ],
        'unread': 1,
        'page': 2,
        'totalPages': 3,
      });
    });
    final r = await svc.listNotifications(page: 2);
    expect(reqs[0].url.path, '/api/notifications');
    expect(reqs[0].url.queryParameters['page'], '2');
    expect(r.items.single.title, 'Received');
    expect(r.items.single.readAt, isNull);
    expect(r.unread, 1);
    expect(r.totalPages, 3);
    await svc.markRead('n1');
    expect(reqs[1].url.path, '/api/notifications/n1/read');
    expect(reqs[1].method, 'POST');
  });
}
