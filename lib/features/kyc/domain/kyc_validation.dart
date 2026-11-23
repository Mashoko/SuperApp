import '../data/kyc_models.dart';

/// Client copy of the server's submission rules (backend/kyc/validation.js,
/// `validateSubmission`). Keys and messages match the server so errors from
/// either side display the same way.

const kycGenders = ['male', 'female', 'other'];
const kycIdTypes = ['national_id', 'passport'];

final _nationalIdPattern =
    RegExp(r'^\d{2}-?\d{6,7}-?[A-Z]-?\d{2}$', caseSensitive: false);
final _passportPattern = RegExp(r'^[A-Z0-9]{6,12}$', caseSensitive: false);

String _text(String? v) => v?.trim() ?? '';

List<String> requiredDocumentKinds(String? idType,
    {bool proofOfResidence = false}) {
  return [
    if (idType == 'national_id') ...['id_front', 'id_back'],
    if (idType == 'passport') 'passport_bio',
    if (proofOfResidence) 'proof_of_residence',
  ];
}

int _ageOn(DateTime dob, DateTime now) {
  var age = now.year - dob.year;
  final monthDiff = now.month - dob.month;
  if (monthDiff < 0 || (monthDiff == 0 && now.day < dob.day)) age -= 1;
  return age;
}

/// [now] defaults to the current time in UTC. Dates in the draft are UTC
/// midnight, as parsed by [KycDraft.fromJson].
///
/// The plain ID number is never sent back by the server. When the user has
/// not typed a new one, an existing [KycIdentification.idNumberMasked] counts
/// as present and its format is left to the server.
Map<String, String> validateKyc(
  KycDraft draft, {
  required List<KycDocumentInfo> documents,
  required bool requireProofOfResidence,
  DateTime? now,
}) {
  final at = (now ?? DateTime.now()).toUtc();
  final errors = <String, String>{};
  final p = draft.personal;
  final a = draft.address;
  final i = draft.identification;

  void length(String key, String? value, int min, int max, String missing) {
    final v = _text(value);
    if (v.isEmpty) {
      errors[key] = missing;
    } else if (v.length < min || v.length > max) {
      errors[key] = 'Use $min to $max characters.';
    }
  }

  length('personal.firstName', p.firstName, 1, 60, 'Enter your first name.');
  length('personal.lastName', p.lastName, 1, 60, 'Enter your last name.');

  final dob = p.dateOfBirth;
  if (dob == null) {
    errors['personal.dateOfBirth'] = 'Enter your date of birth.';
  } else {
    final age = _ageOn(dob, at);
    if (age < 16) {
      errors['personal.dateOfBirth'] = 'You must be at least 16 years old.';
    } else if (age > 120) {
      errors['personal.dateOfBirth'] = 'Enter a valid date of birth.';
    }
  }

  if (!kycGenders.contains(_text(p.gender))) {
    errors['personal.gender'] = 'Choose your gender.';
  }
  length('personal.nationality', p.nationality, 2, 56,
      'Enter your nationality.');

  length('address.line1', a.line1, 1, 120, 'Enter your street address.');
  if (_text(a.line2).length > 120) {
    errors['address.line2'] = 'Use 120 characters or fewer.';
  }
  length('address.city', a.city, 1, 60, 'Enter your city or town.');
  length('address.country', a.country, 2, 56, 'Enter your country.');

  final idType = _text(i.idType);
  if (!kycIdTypes.contains(idType)) {
    errors['identification.idType'] = 'Choose an ID type.';
  }

  final typed = _text(i.newIdNumber);
  if (typed.isEmpty) {
    if (_text(i.idNumberMasked).isEmpty) {
      errors['identification.idNumber'] = 'Enter your ID number.';
    }
  } else if (idType == 'national_id' && !_nationalIdPattern.hasMatch(typed)) {
    errors['identification.idNumber'] =
        'Enter a valid national ID number, like 63-123456-A-42.';
  } else if (idType == 'passport' && !_passportPattern.hasMatch(typed)) {
    errors['identification.idNumber'] =
        'Enter a valid passport number (6 to 12 letters or digits).';
  }

  if (idType == 'passport') {
    final expiry = i.idExpiry;
    if (expiry == null) {
      errors['identification.idExpiry'] = 'Enter your passport expiry date.';
    } else if (!expiry.isAfter(at)) {
      errors['identification.idExpiry'] = 'Your passport has expired.';
    }
  }

  final present = {for (final d in documents) d.kind};
  for (final kind in requiredDocumentKinds(idType,
      proofOfResidence: requireProofOfResidence)) {
    if (!present.contains(kind)) errors['documents.$kind'] = 'Upload this document.';
  }

  return errors;
}

const _stepPrefixes = ['personal.', 'address.', 'identification.', 'documents.'];

/// 0 Personal, 1 Address, 2 ID details, 3 Documents; anything else is shown
/// on 4 Review.
int kycStepForKey(String key) {
  for (var s = 0; s < _stepPrefixes.length; s++) {
    if (key.startsWith(_stepPrefixes[s])) return s;
  }
  return 4;
}

Map<String, String> errorsForStep(Map<String, String> errors, int step) => {
      for (final e in errors.entries)
        if (kycStepForKey(e.key) == step) e.key: e.value,
    };
