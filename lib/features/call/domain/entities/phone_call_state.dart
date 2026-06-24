/// UI-level call state machine — distinct from sip_ua's low-level CallStateEnum.
/// The ViewModel translates raw SIP events into these states for the UI to consume.
enum PhoneCallState {
  idle,      // No active call
  calling,   // Outgoing: SIP INVITE sent, waiting for any response
  ringing,   // Outgoing: received SIP 180 — remote device is ringing
  incoming,  // Incoming: our device is ringing, waiting for user action
  connected, // Both parties are talking — timer starts HERE
  ended,     // Normal hang-up by either party
  missed,    // Incoming: caller cancelled before answer
  declined,  // Incoming: local user rejected the call
  failed,    // Could not connect at all
}

extension PhoneCallStateX on PhoneCallState {
  bool get isPreConnect =>
      this == PhoneCallState.calling ||
      this == PhoneCallState.ringing ||
      this == PhoneCallState.incoming;

  bool get isTerminal =>
      this == PhoneCallState.ended ||
      this == PhoneCallState.missed ||
      this == PhoneCallState.declined ||
      this == PhoneCallState.failed;

  bool get showTimer => this == PhoneCallState.connected;

  String statusLabel({bool isOnHold = false}) {
    if (isOnHold && this == PhoneCallState.connected) return 'On Hold';
    switch (this) {
      case PhoneCallState.calling:   return 'Calling...';
      case PhoneCallState.ringing:   return 'Ringing...';
      case PhoneCallState.incoming:  return 'Incoming Call';
      case PhoneCallState.connected: return 'Connected';
      case PhoneCallState.ended:     return 'Call Ended';
      case PhoneCallState.missed:    return 'Missed Call';
      case PhoneCallState.declined:  return 'Call Declined';
      case PhoneCallState.failed:    return 'Call Failed';
      case PhoneCallState.idle:      return '';
    }
  }
}
