// User-facing labels shared by the KYC screens.

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
