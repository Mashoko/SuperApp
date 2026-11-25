import 'package:flutter/foundation.dart';

/// App-wide record of an outgoing emergency call that started and then
/// failed (or ended without connecting), so the app can offer the phone's
/// own dialer once the call screen has closed.
///
/// Holds only the latest pending number. Written by `SipCallManager`, read
/// by the KYC gate, which shows the "Call not started" dialog.
class EmergencyCallFailures extends ValueNotifier<String?> {
  EmergencyCallFailures() : super(null);

  void report(String number) => value = number;

  /// Returns the pending number, if any, and clears it.
  String? take() {
    final number = value;
    value = null;
    return number;
  }
}
