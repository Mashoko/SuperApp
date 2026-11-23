/// Numbers that may always be dialled, even while KYC restrictions apply.
///
/// [CONFIRM WITH COMPLIANCE]: this list is provisional. Update it here only.
const List<String> kEmergencyNumbers = ['999', '993', '994', '995', '112'];

/// True when [raw], reduced to digits only, equals an emergency number.
bool isEmergencyNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return kEmergencyNumbers.contains(digits);
}
