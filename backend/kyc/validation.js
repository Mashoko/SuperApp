// Validation for KYC drafts (lenient: types and lengths only) and submissions (strict).
// Error keys are field paths like 'personal.firstName' or 'documents.id_front'.
// Messages are user-facing and must never echo the submitted value.

const ID_TYPES = ['national_id', 'passport'];
const GENDERS = ['male', 'female', 'other'];

// Max lengths for every field a draft may hold. Unknown fields are ignored by callers.
const DRAFT_FIELDS = Object.freeze({
  personal: { firstName: 60, lastName: 60, dateOfBirth: 10, gender: 10, nationality: 56 },
  address: { line1: 120, line2: 120, city: 60, country: 56 },
  identification: { idType: 20, idNumber: 20, idExpiry: 10 },
});

const NATIONAL_ID_PATTERN = /^\d{2}-?\d{6,7}-?[A-Z]-?\d{2}$/i;
const PASSPORT_PATTERN = /^[A-Z0-9]{6,12}$/i;
const ISO_DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

const isPlainObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

function validateDraft(data) {
  const errors = {};
  if (!isPlainObject(data)) {
    return { ok: false, errors: { data: 'Draft details are missing or invalid.' } };
  }
  for (const [section, fields] of Object.entries(DRAFT_FIELDS)) {
    const value = data[section];
    if (value === undefined || value === null) continue;
    if (!isPlainObject(value)) {
      errors[section] = 'This section is invalid.';
      continue;
    }
    for (const [field, max] of Object.entries(fields)) {
      const v = value[field];
      if (v === undefined || v === null) continue;
      const key = `${section}.${field}`;
      if (typeof v !== 'string') errors[key] = 'Enter this as text.';
      else if (v.trim().length > max) errors[key] = `Use ${max} characters or fewer.`;
    }
  }
  return { ok: Object.keys(errors).length === 0, errors };
}

const text = (v) => (typeof v === 'string' ? v.trim() : '');

// Returns a UTC Date for a strict YYYY-MM-DD string, otherwise null.
function parseIsoDate(v) {
  const m = ISO_DATE_PATTERN.exec(text(v));
  if (!m) return null;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const date = new Date(Date.UTC(y, mo - 1, d));
  if (date.getUTCFullYear() !== y || date.getUTCMonth() !== mo - 1 || date.getUTCDate() !== d) {
    return null;
  }
  return date;
}

function ageOn(dob, now) {
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  const monthDiff = now.getUTCMonth() - dob.getUTCMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getUTCDate() < dob.getUTCDate())) age -= 1;
  return age;
}

function requiredDocumentKinds(idType) {
  const kinds = [];
  if (idType === 'national_id') kinds.push('id_front', 'id_back');
  if (idType === 'passport') kinds.push('passport_bio');
  if (process.env.KYC_REQUIRE_PROOF_OF_RESIDENCE === 'true') kinds.push('proof_of_residence');
  return kinds;
}

// `data` holds the plaintext idNumber (decrypted by the caller); `docs` is a list of
// { kind } for the user's draft documents.
function validateSubmission(data, docs = [], now = new Date()) {
  const errors = {};
  const personal = isPlainObject(data?.personal) ? data.personal : {};
  const address = isPlainObject(data?.address) ? data.address : {};
  const identification = isPlainObject(data?.identification) ? data.identification : {};

  const length = (key, value, min, max, missing) => {
    const v = text(value);
    if (!v) errors[key] = missing;
    else if (v.length < min || v.length > max) {
      errors[key] = `Use ${min} to ${max} characters.`;
    }
  };

  length('personal.firstName', personal.firstName, 1, 60, 'Enter your first name.');
  length('personal.lastName', personal.lastName, 1, 60, 'Enter your last name.');

  const dob = parseIsoDate(personal.dateOfBirth);
  if (!text(personal.dateOfBirth)) errors['personal.dateOfBirth'] = 'Enter your date of birth.';
  else if (!dob) errors['personal.dateOfBirth'] = 'Enter a valid date of birth.';
  else {
    const age = ageOn(dob, now);
    if (age < 16) errors['personal.dateOfBirth'] = 'You must be at least 16 years old.';
    else if (age > 120) errors['personal.dateOfBirth'] = 'Enter a valid date of birth.';
  }

  if (!GENDERS.includes(text(personal.gender))) errors['personal.gender'] = 'Choose your gender.';
  length('personal.nationality', personal.nationality, 2, 56, 'Enter your nationality.');

  length('address.line1', address.line1, 1, 120, 'Enter your street address.');
  if (text(address.line2).length > 120) errors['address.line2'] = 'Use 120 characters or fewer.';
  length('address.city', address.city, 1, 60, 'Enter your city or town.');
  length('address.country', address.country, 2, 56, 'Enter your country.');

  const idType = text(identification.idType);
  const idNumber = text(identification.idNumber);
  if (!ID_TYPES.includes(idType)) errors['identification.idType'] = 'Choose an ID type.';

  if (!idNumber) errors['identification.idNumber'] = 'Enter your ID number.';
  else if (idType === 'national_id' && !NATIONAL_ID_PATTERN.test(idNumber)) {
    errors['identification.idNumber'] = 'Enter a valid national ID number, like 63-123456-A-42.';
  } else if (idType === 'passport' && !PASSPORT_PATTERN.test(idNumber)) {
    errors['identification.idNumber'] = 'Enter a valid passport number (6 to 12 letters or digits).';
  }

  const expiryRaw = text(identification.idExpiry);
  const expiry = parseIsoDate(expiryRaw);
  if (idType === 'passport') {
    if (!expiryRaw) errors['identification.idExpiry'] = 'Enter your passport expiry date.';
    else if (!expiry) errors['identification.idExpiry'] = 'Enter a valid expiry date.';
    else if (expiry.getTime() <= now.getTime()) {
      errors['identification.idExpiry'] = 'Your passport has expired.';
    }
  } else if (expiryRaw && !expiry) {
    errors['identification.idExpiry'] = 'Enter a valid expiry date.';
  }

  const present = new Set((docs || []).map((d) => d.kind));
  for (const kind of requiredDocumentKinds(idType)) {
    if (!present.has(kind)) errors[`documents.${kind}`] = 'Upload this document.';
  }

  return { ok: Object.keys(errors).length === 0, errors };
}

module.exports = {
  DRAFT_FIELDS,
  ID_TYPES,
  GENDERS,
  validateDraft,
  validateSubmission,
  requiredDocumentKinds,
  parseIsoDate,
};
