import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/domain/kyc_validation.dart';

final _now = DateTime.utc(2026, 11, 23, 12);

KycDocumentInfo _doc(String kind) =>
    KycDocumentInfo(id: kind, kind: kind, mime: 'image/jpeg', size: 10);

const _validPersonal = KycPersonal(
  firstName: 'Tendai',
  lastName: 'Moyo',
  gender: 'female',
  nationality: 'Zimbabwean',
);

KycDraft _draft({
  KycPersonal? personal,
  KycAddress? address,
  KycIdentification? identification,
  DateTime? dob,
}) =>
    KycDraft(
      personal: personal ??
          KycPersonal(
            firstName: _validPersonal.firstName,
            lastName: _validPersonal.lastName,
            gender: _validPersonal.gender,
            nationality: _validPersonal.nationality,
            dateOfBirth: dob ?? DateTime.utc(1990, 5, 4),
          ),
      address: address ??
          const KycAddress(line1: '12 Samora Machel Ave', city: 'Harare', country: 'Zimbabwe'),
      identification: identification ??
          const KycIdentification(
              idType: 'national_id', newIdNumber: '63-123456-A-42'),
    );

Map<String, String> _v(
  KycDraft d, {
  List<KycDocumentInfo>? docs,
  bool proof = false,
}) =>
    validateKyc(
      d,
      documents: docs ?? [_doc('id_front'), _doc('id_back')],
      requireProofOfResidence: proof,
      now: _now,
    );

void main() {
  test('a complete national ID draft passes', () {
    expect(_v(_draft()), isEmpty);
  });

  test('a complete passport draft passes', () {
    final d = _draft(
      identification: KycIdentification(
          idType: 'passport',
          newIdNumber: 'FN123456',
          idExpiry: DateTime.utc(2030, 1, 1)),
    );
    expect(_v(d, docs: [_doc('passport_bio')]), isEmpty);
  });

  group('personal', () {
    test('names required and 1 to 60 characters', () {
      final e = _v(_draft(
          personal: KycPersonal(
              firstName: '  ',
              lastName: 'x' * 61,
              gender: 'male',
              nationality: 'ZW',
              dateOfBirth: DateTime.utc(1990))));
      expect(e['personal.firstName'], 'Enter your first name.');
      expect(e['personal.lastName'], 'Use 1 to 60 characters.');
    });

    test('date of birth missing, under 16, over 120', () {
      KycDraft withDob(DateTime? dob) => KycDraft(
          personal: KycPersonal(
              firstName: 'a',
              lastName: 'b',
              gender: 'other',
              nationality: 'ZW',
              dateOfBirth: dob));
      expect(_v(withDob(null))['personal.dateOfBirth'],
          'Enter your date of birth.');
      // Turns 16 tomorrow.
      expect(_v(withDob(DateTime.utc(2010, 11, 24)))['personal.dateOfBirth'],
          'You must be at least 16 years old.');
      // Turns 16 today.
      expect(_v(withDob(DateTime.utc(2010, 11, 23))),
          isNot(contains('personal.dateOfBirth')));
      expect(_v(withDob(DateTime.utc(1905, 1, 1)))['personal.dateOfBirth'],
          'Enter a valid date of birth.');
      expect(_v(withDob(DateTime.utc(1906, 11, 23))),
          isNot(contains('personal.dateOfBirth')));
    });

    test('gender must be male, female or other', () {
      KycDraft g(String? gender) => KycDraft(
          personal: KycPersonal(
              firstName: 'a',
              lastName: 'b',
              gender: gender,
              nationality: 'ZW',
              dateOfBirth: DateTime.utc(1990)));
      expect(_v(g(null))['personal.gender'], 'Choose your gender.');
      expect(_v(g('unknown'))['personal.gender'], 'Choose your gender.');
      for (final ok in ['male', 'female', 'other']) {
        expect(_v(g(ok)), isNot(contains('personal.gender')));
      }
    });

    test('nationality 2 to 56 characters', () {
      KycDraft n(String? v) => KycDraft(
          personal: KycPersonal(
              firstName: 'a',
              lastName: 'b',
              gender: 'male',
              nationality: v,
              dateOfBirth: DateTime.utc(1990)));
      expect(_v(n(null))['personal.nationality'], 'Enter your nationality.');
      expect(_v(n('Z'))['personal.nationality'], 'Use 2 to 56 characters.');
      expect(_v(n('Z' * 57))['personal.nationality'], 'Use 2 to 56 characters.');
    });
  });

  group('address', () {
    test('line1, city, country required with length limits', () {
      final e = _v(_draft(address: const KycAddress()));
      expect(e['address.line1'], 'Enter your street address.');
      expect(e['address.city'], 'Enter your city or town.');
      expect(e['address.country'], 'Enter your country.');
      final e2 = _v(_draft(
          address: KycAddress(
              line1: 'x' * 121,
              line2: 'y' * 121,
              city: 'c' * 61,
              country: 'Z')));
      expect(e2['address.line1'], 'Use 1 to 120 characters.');
      expect(e2['address.line2'], 'Use 120 characters or fewer.');
      expect(e2['address.city'], 'Use 1 to 60 characters.');
      expect(e2['address.country'], 'Use 2 to 56 characters.');
    });
  });

  group('identification', () {
    test('ID type required', () {
      final e = _v(_draft(
          identification: const KycIdentification(newIdNumber: '63-123456-A-42')));
      expect(e['identification.idType'], 'Choose an ID type.');
    });

    test('national ID number format (case-insensitive, optional dashes)', () {
      Map<String, String> n(String v) => _v(_draft(
          identification:
              KycIdentification(idType: 'national_id', newIdNumber: v)));
      for (final ok in ['63-123456-A-42', '631234567a42', '63-1234567-b42']) {
        expect(n(ok), isNot(contains('identification.idNumber')), reason: ok);
      }
      for (final bad in ['63-12345-A-42', '63-123456-42', 'AB-123456-A-42']) {
        expect(n(bad)['identification.idNumber'],
            'Enter a valid national ID number, like 63-123456-A-42.',
            reason: bad);
      }
    });

    test('passport number format and expiry', () {
      Map<String, String> p(String v, DateTime? exp) => _v(
          _draft(
              identification: KycIdentification(
                  idType: 'passport', newIdNumber: v, idExpiry: exp)),
          docs: [_doc('passport_bio')]);
      expect(p('fn1234', DateTime.utc(2030)), isEmpty);
      expect(p('FN12-34', DateTime.utc(2030))['identification.idNumber'],
          'Enter a valid passport number (6 to 12 letters or digits).');
      expect(p('FN123', DateTime.utc(2030))['identification.idNumber'],
          'Enter a valid passport number (6 to 12 letters or digits).');
      expect(p('FN1234567890123', DateTime.utc(2030))['identification.idNumber'],
          'Enter a valid passport number (6 to 12 letters or digits).');
      expect(p('FN123456', null)['identification.idExpiry'],
          'Enter your passport expiry date.');
      // Today at midnight UTC is already past "now".
      expect(p('FN123456', DateTime.utc(2026, 11, 23))['identification.idExpiry'],
          'Your passport has expired.');
      expect(p('FN123456', DateTime.utc(2026, 11, 24)), isEmpty);
    });

    test('ID number missing, or kept on the server via the masked value', () {
      expect(
          _v(_draft(
                  identification:
                      const KycIdentification(idType: 'national_id')))[
              'identification.idNumber'],
          'Enter your ID number.');
      expect(
          _v(_draft(
              identification: const KycIdentification(
                  idType: 'national_id', idNumberMasked: '******A42'))),
          isEmpty);
    });

    test('national ID expiry is optional', () {
      expect(
          _v(_draft(
              identification: const KycIdentification(
                  idType: 'national_id', newIdNumber: '63-123456-A-42'))),
          isEmpty);
    });
  });

  group('documents', () {
    test('national ID needs front and back', () {
      final e = _v(_draft(), docs: [_doc('id_front')]);
      expect(e['documents.id_back'], 'Upload this document.');
      expect(e, isNot(contains('documents.id_front')));
    });

    test('passport needs the photo page', () {
      final e = _v(
          _draft(
              identification: KycIdentification(
                  idType: 'passport',
                  newIdNumber: 'FN123456',
                  idExpiry: DateTime.utc(2030))),
          docs: []);
      expect(e.keys.where((k) => k.startsWith('documents.')),
          ['documents.passport_bio']);
    });

    test('proof of residence only when required', () {
      expect(_v(_draft()), isNot(contains('documents.proof_of_residence')));
      expect(_v(_draft(), proof: true)['documents.proof_of_residence'],
          'Upload this document.');
      expect(
          _v(_draft(),
              proof: true,
              docs: [_doc('id_front'), _doc('id_back'), _doc('proof_of_residence')]),
          isEmpty);
    });

    test('requiredDocumentKinds', () {
      expect(requiredDocumentKinds('national_id'), ['id_front', 'id_back']);
      expect(requiredDocumentKinds('passport', proofOfResidence: true),
          ['passport_bio', 'proof_of_residence']);
      expect(requiredDocumentKinds(null), isEmpty);
    });
  });

  test('stepForKey and errorsForStep', () {
    expect(kycStepForKey('personal.firstName'), 0);
    expect(kycStepForKey('address.city'), 1);
    expect(kycStepForKey('identification.idNumber'), 2);
    expect(kycStepForKey('documents.id_front'), 3);
    expect(kycStepForKey('data'), 4);
    final e = _v(const KycDraft());
    expect(e.keys.every((k) => k.contains('.')), isTrue);
    expect(errorsForStep(e, 1).keys.every((k) => k.startsWith('address.')),
        isTrue);
  });
}
