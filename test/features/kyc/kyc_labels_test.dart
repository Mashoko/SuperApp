import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_labels.dart';

import 'kyc_test_fakes.dart';

void main() {
  group('kycVerificationSubtitle (Profile tile)', () {
    test('is "Checking…" while no status has loaded', () {
      expect(kycVerificationSubtitle(null), 'Checking…');
    });

    test('offers a retry when the first load failed', () {
      expect(kycVerificationSubtitle(null, error: 'You are offline.'),
          'Could not load. Tap to try again.');
    });

    test('is "Not open yet" only once loaded and not launched', () {
      expect(
          kycVerificationSubtitle(
              kycStatus(status: 'NOT_STARTED', launched: false)),
          'Not open yet');
    });

    test('is the status label when launched', () {
      expect(kycVerificationSubtitle(kycStatus(status: 'APPROVED')), 'Verified');
      expect(kycVerificationSubtitle(kycStatus(status: 'RESTRICTED')),
          'Action needed');
    });
  });
}
