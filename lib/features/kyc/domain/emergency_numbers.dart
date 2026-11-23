/// Numbers that may always be dialled, even while KYC restrictions apply.
///
/// [CONFIRM WITH COMPLIANCE]: this list is provisional. Update it here only.
const List<String> kEmergencyNumbers = ['999', '993', '994', '995', '112'];

const String kKycCallBlockedMessage =
    'Calls are paused until you complete your KYC verification. Emergency calls still work.';

/// Returns the message to show when an outgoing call to [number] must be
/// refused because KYC restrictions apply, or null when the call may proceed.
String? kycCallBlockReason(
  String number, {
  required bool Function() isRestricted,
}) {
  if (isRestricted() && !isEmergencyNumber(number)) {
    return kKycCallBlockedMessage;
  }
  return null;
}

/// True when [raw], reduced to digits only, equals an emergency number.
bool isEmergencyNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return kEmergencyNumbers.contains(digits);
}
