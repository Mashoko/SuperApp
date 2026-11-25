import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/domain/emergency_numbers.dart';

void main() {
  test('kycCallBlockReason', () {
    expect(kycCallBlockReason('0770000000', isRestricted: () => true),
        kKycCallBlockedMessage);
    expect(kycCallBlockReason('999', isRestricted: () => true), isNull);
    expect(
        kycCallBlockReason('0770000000', isRestricted: () => false), isNull);
  });

  test('fails open and never consults restriction for emergency numbers', () {
    bool boom() => throw StateError('controller failed');
    expect(kycCallBlockReason('999', isRestricted: boom), isNull);
    expect(kycCallBlockReason('0770000000', isRestricted: boom), isNull);
  });

  test('recognises emergency numbers ignoring allowed formatting', () {
    for (final n in [
      '999', '+999', '99 9', '(999)', '9-9.9', '112', '993', '994', '995'
    ]) {
      expect(isEmergencyNumber(n), isTrue, reason: n);
    }
  });

  test('rejects non emergency numbers and bypass attempts', () {
    for (final n in [
      '0999123', '9990', '', '*999', '#999', '999abc', '9@9.9', 'sip:999@x',
      '++999', '+', '9+99'
    ]) {
      expect(isEmergencyNumber(n), isFalse, reason: n);
    }
  });

  group('emergencyNumberFromSipIdentity', () {
    test('reads the number from the shapes the SIP stack reports', () {
      // sip_ua's Call.remote_identity is the URI user part ('999'); the
      // other shapes are full To/From header values.
      final cases = {
        '999': '999',
        '+999': '999',
        '112': '112',
        'sip:999@domain': '999',
        '<sip:999@domain>': '999',
        'sips:993@sip.example.com:5061': '993',
        '"Name" <sip:112@x>': '112',
        'Name <sip:995@x;transport=ws>': '995',
        'tel:999': '999',
        'tel:+112;phone-context=x': '112',
        ' sip:994@x ': '994',
      };
      cases.forEach((identity, number) {
        expect(emergencyNumberFromSipIdentity(identity), number,
            reason: identity);
      });
    });

    test('returns null for anything that is not an emergency number', () {
      for (final identity in [
        null, '', '   ', 'sip:0999123@x', 'sip:alice@x', '0770000000',
        'sip:9990@x', '<sip:@x>', 'sip:*999@x', 'http:999', 'sip:', '<>',
      ]) {
        expect(emergencyNumberFromSipIdentity(identity), isNull,
            reason: '$identity');
      }
    });
  });
}
