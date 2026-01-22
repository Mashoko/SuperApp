enum CallStatus {
  initiated,
  ringing,
  connected,
  ended,
  missed,
  rejected,
}

extension CallStatusExtension on CallStatus {
  String get value {
    switch (this) {
      case CallStatus.initiated:
        return 'initiated';
      case CallStatus.ringing:
        return 'ringing';
      case CallStatus.connected:
        return 'connected';
      case CallStatus.ended:
        return 'ended';
      case CallStatus.missed:
        return 'missed';
      case CallStatus.rejected:
        return 'rejected';
    }
  }

  static CallStatus fromString(String value) {
    switch (value) {
      case 'initiated':
        return CallStatus.initiated;
      case 'ringing':
        return CallStatus.ringing;
      case 'connected':
        return CallStatus.connected;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      case 'rejected':
        return CallStatus.rejected;
      default:
        return CallStatus.initiated;
    }
  }
}

