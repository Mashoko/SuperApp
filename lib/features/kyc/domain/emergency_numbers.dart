/// Numbers that may always be dialled, even while KYC restrictions apply.
///
/// [CONFIRM WITH COMPLIANCE]: this list is provisional. Update it here only.
const List<String> kEmergencyNumbers = ['999', '993', '994', '995', '112'];

const String kKycCallBlockedMessage =
    'Calls are paused until you complete your KYC verification. Emergency calls still work.';

/// True when [raw] is an emergency number. Only spaces, '-', '(', ')', '.'
/// and a single leading '+' are ignored; anything else non-numeric (such as
/// '*', '#', letters or a SIP URI) means it is not an emergency number.
bool isEmergencyNumber(String raw) {
  var s = raw.trim();
  if (s.startsWith('+')) s = s.substring(1);
  s = s.replaceAll(RegExp(r'[ \-().]'), '');
  if (!RegExp(r'^[0-9]+$').hasMatch(s)) return false;
  return kEmergencyNumbers.contains(s);
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
