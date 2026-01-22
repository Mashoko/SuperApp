
import 'bill_type.dart';
import 'bill_status.dart';

class UtilityBillPayment {
  final String paymentId;
  final String userId;
  final UtilityBillType billType;
  final String provider;
  final String accountOrMeter;
  final double amount;
  final DateTime timestamp;
  final UtilityBillStatus status;
  final String? reference;

  UtilityBillPayment({
    required this.paymentId,
    required this.userId,
    required this.billType,
    required this.provider,
    required this.accountOrMeter,
    required this.amount,
    required this.timestamp,
    required this.status,
    this.reference,
  });
}
