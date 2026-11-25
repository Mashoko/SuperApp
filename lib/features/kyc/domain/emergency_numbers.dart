/// Numbers that may always be dialled, even while KYC restrictions apply.
///
/// [CONFIRM WITH COMPLIANCE]: this list is provisional. Update it here only.
const List<String> kEmergencyNumbers = ['999', '993', '994', '995', '112'];

const String kKycCallBlockedMessage =
    'Calls are paused until you complete your KYC verification. Emergency calls still work.';

/// True when [raw] is an emergency number. Only spaces, '-', '(', ')', '.'
/// and a single leading '+' are ignored; anything else non-numeric (such as
/// '*', '#', letters or a SIP URI) means it is not an emergency number.
bool isEmergencyNumber(String raw) => _normalisedEmergencyNumber(raw) != null;

/// The entry of [kEmergencyNumbers] that [raw] dials, or null. Same rules
/// as [isEmergencyNumber].
String? _normalisedEmergencyNumber(String raw) {
  var s = raw.trim();
  if (s.startsWith('+')) s = s.substring(1);
  s = s.replaceAll(RegExp(r'[ \-().]'), '');
  if (!RegExp(r'^[0-9]+$').hasMatch(s)) return null;
  return kEmergencyNumbers.contains(s) ? s : null;
}

/// Reads the dialled number from an identity reported by the SIP stack and
/// returns it (as listed in [kEmergencyNumbers]) when it is an emergency
/// number, otherwise null.
///
/// sip_ua's `Call.remote_identity` is normally just the URI user part
/// ('999'), but full header values are accepted too: an optional display
/// name and angle brackets, an optional `sip:`, `sips:` or `tel:` scheme,
/// and anything from `@` or `;` onwards are ignored.
///
/// For the SIP stack's own values only. Typed input must go through
/// [isEmergencyNumber], which deliberately refuses SIP URIs.
String? emergencyNumberFromSipIdentity(String? identity) {
  if (identity == null) return null;
  var s = identity.trim();
  final open = s.indexOf('<');
  if (open >= 0) {
    final close = s.indexOf('>', open);
    s = s.substring(open + 1, close < 0 ? s.length : close).trim();
  }
  final scheme =
      RegExp(r'^(sips?|tel):', caseSensitive: false).firstMatch(s);
  if (scheme != null) s = s.substring(scheme.end);
  final end = s.indexOf(RegExp('[@;]'));
  if (end >= 0) s = s.substring(0, end);
  return _normalisedEmergencyNumber(s);
}

/// Returns the message to show when an outgoing call to [number] must be
/// refused because KYC restrictions apply, or null when the call may proceed.
/// Emergency numbers are checked first and never depend on [isRestricted],
/// which fails open if it throws.
String? kycCallBlockReason(
  String number, {
  required bool Function() isRestricted,
}) {
  if (isEmergencyNumber(number)) return null;
  try {
    if (!isRestricted()) return null;
  } catch (_) {
    return null;
  }
  return kKycCallBlockedMessage;
}
