enum PaymentMethodType { visa, mastercard, ecocash, onemoney, innbucks, bank, paypal }

enum MethodStatus { defaultMethod, verified, pending }

class PaymentMethod {
  final String id;
  final PaymentMethodType type;
  final String displayName;
  final String subtitle;
  final MethodStatus status;

  const PaymentMethod({
    required this.id,
    required this.type,
    required this.displayName,
    required this.subtitle,
    required this.status,
  });

  PaymentMethod copyWith({
    String? displayName,
    String? subtitle,
    MethodStatus? status,
  }) =>
      PaymentMethod(
        id: id,
        type: type,
        displayName: displayName ?? this.displayName,
        subtitle: subtitle ?? this.subtitle,
        status: status ?? this.status,
      );
}
