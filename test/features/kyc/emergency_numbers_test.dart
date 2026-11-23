import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/domain/emergency_numbers.dart';

void main() {
  test('kycCallBlockReason', () {
    expect(kycCallBlockReason('0771234567', isRestricted: () => true),
        kKycCallBlockedMessage);
    expect(kycCallBlockReason('999', isRestricted: () => true), isNull);
    expect(
        kycCallBlockReason('0771234567', isRestricted: () => false), isNull);
  });

  test('recognises emergency numbers ignoring formatting', () {
    for (final n in ['999', '+999', '99 9', '112', '993', '994', '995']) {
      expect(isEmergencyNumber(n), isTrue, reason: n);
    }
  });

  test('rejects non emergency numbers', () {
    for (final n in ['0999123', '9990', '']) {
      expect(isEmergencyNumber(n), isFalse, reason: n);
    }
  });
}
