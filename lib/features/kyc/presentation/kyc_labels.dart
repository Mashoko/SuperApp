// User-facing labels shared by the KYC screens.

import 'package:intl/intl.dart';

import '../data/kyc_models.dart';

final _localDate = DateFormat('d MMMM y');

/// Formats a server timestamp (deadline, submission, decision, update) in the
/// device's local time, like "23 December 2026".
String kycLocalDate(DateTime d) => _localDate.format(d.toLocal());

const kycDocumentKindLabels = <String, String>{
  'id_front': 'National ID, front',
  'id_back': 'National ID, back',
  'passport_bio': 'Passport photo page',
  'proof_of_residence': 'Proof of residence',
};

String kycDocumentLabel(String kind) => kycDocumentKindLabels[kind] ?? 'Document';

/// Labels for field keys used in `outstanding` and in error maps, like
/// `personal.firstName` or `documents.id_front`.
const kycFieldLabels = <String, String>{
  'personal.firstName': 'First name',
  'personal.lastName': 'Last name',
  'personal.dateOfBirth': 'Date of birth',
  'personal.gender': 'Gender',
  'personal.nationality': 'Nationality',
  'address.line1': 'Address',
  'address.line2': 'Address line 2',
  'address.city': 'City or town',
  'address.country': 'Country',
  'identification.idType': 'ID type',
  'identification.idNumber': 'ID number',
  'identification.idExpiry': 'Expiry date',
};

String kycFieldLabel(String key) {
  if (key.startsWith('documents.')) {
    return kycDocumentLabel(key.substring('documents.'.length));
  }
  return kycFieldLabels[key] ?? 'Other details';
}

const kycGenderLabels = <String, String>{
  'male': 'Male',
  'female': 'Female',
  'other': 'Other',
};

const kycIdTypeLabels = <String, String>{
  'national_id': 'National ID',
  'passport': 'Passport',
};

/// Labels for the user-facing KYC status.
const kycStatusLabels = <String, String>{
  'NOT_STARTED': 'Not started',
  'IN_PROGRESS': 'In progress',
  'PENDING_REVIEW': 'Under review',
  'APPROVED': 'Verified',
  'REJECTED': 'Not approved',
  'REQUIRES_CORRECTION': 'Needs a correction',
  'EXPIRED': 'Expired',
  'RESTRICTED': 'Action needed',
};

String kycStatusLabel(String status) =>
    kycStatusLabels[status] ?? kycStatusLabels['NOT_STARTED']!;

/// Labels for a submission's `decision` in the history list.
const kycDecisionLabels = <String, String>{
  'pending': 'Under review',
  'approved': 'Verified',
  'rejected': 'Not approved',
  'requires_correction': 'Needs a correction',
};

String kycDecisionLabel(String decision) =>
    kycDecisionLabels[decision] ?? 'Under review';

/// Subtitle for the Profile "Verification" tile. "Not open yet" only once a
/// status has loaded and verification is not launched.
String kycVerificationSubtitle(KycStatus? status, {String? error}) {
  if (status == null) {
    return error == null ? 'Checking…' : 'Could not load. Tap to try again.';
  }
  return status.launched ? kycStatusLabel(status.status) : 'Not open yet';
}
