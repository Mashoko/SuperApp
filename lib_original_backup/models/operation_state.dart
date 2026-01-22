enum OperationStatus { idle, loading, success, error }

class OperationState {
  const OperationState({
    required this.status,
    this.message,
  });

  final OperationStatus status;
  final String? message;

  bool get isLoading => status == OperationStatus.loading;
  bool get hasError => status == OperationStatus.error;

  OperationState copyWith({
    OperationStatus? status,
    String? message,
  }) {
    return OperationState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  static const idle = OperationState(status: OperationStatus.idle);

  static OperationState loading([String? message]) => OperationState(
        status: OperationStatus.loading,
        message: message,
      );

  static OperationState success([String? message]) => OperationState(
        status: OperationStatus.success,
        message: message,
      );

  static OperationState error([String? message]) => OperationState(
        status: OperationStatus.error,
        message: message,
      );
}

