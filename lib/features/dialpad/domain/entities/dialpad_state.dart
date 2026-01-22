class DialpadState {
  final String destination;
  final String registrationStatus;

  DialpadState({
    required this.destination,
    required this.registrationStatus,
  });

  DialpadState copyWith({
    String? destination,
    String? registrationStatus,
  }) {
    return DialpadState(
      destination: destination ?? this.destination,
      registrationStatus: registrationStatus ?? this.registrationStatus,
    );
  }
}

