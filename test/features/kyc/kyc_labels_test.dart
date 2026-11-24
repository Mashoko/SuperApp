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

  group('kycDecisionLabel (submission history)', () {
    // Values from KYC_DECISIONS in backend/kyc/models/kyc_submission.model.js.
    test('labels every decision the server sends', () {
      expect(kycDecisionLabel('pending'), 'Under review');
      expect(kycDecisionLabel('approved'), 'Verified');
      expect(kycDecisionLabel('rejected'), 'Not approved');
      expect(kycDecisionLabel('correction_requested'), 'Needs a correction');
      expect(kycDecisionLabel('expired'), 'Expired');
    });
  });
}
