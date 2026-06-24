import 'payment_method.dart';

enum TransactionStatus { completed, pending, failed }

class PmTransaction {
  final String id;
  final String title;
  final DateTime date;
  final PaymentMethodType methodType;
  final String methodLabel;
  final String reference;
  final double amount;
  final TransactionStatus status;

  const PmTransaction({
    required this.id,
    required this.title,
    required this.date,
    required this.methodType,
    required this.methodLabel,
    required this.reference,
    required this.amount,
    required this.status,
  });
}
