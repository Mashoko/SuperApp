// Canonical form of a SIP username, used as the user identity key everywhere.
// Phone numbers become '+' followed by digits, so '263 77-123 4567', '263771234567'
// and '+263771234567' all map to '+263771234567'. Anything else (a non-phone SIP
// username) is returned trimmed but otherwise unchanged.
const canonicalUsername = (raw) => {
  const trimmed = String(raw).trim();
  const compact = trimmed.replace(/[\s\-()]/g, '');
  if (/^\+?\d+$/.test(compact)) return `+${compact.replace(/^\+/, '')}`;
  return trimmed;
};

module.exports = { canonicalUsername };
