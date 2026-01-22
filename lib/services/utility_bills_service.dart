
import 'package:mvvm_sip_demo/models/utility_bills/bill_payment.dart';
import 'package:mvvm_sip_demo/models/utility_bills/bill_status.dart';
import 'package:mvvm_sip_demo/models/utility_bills/bill_type.dart';

class UtilityBillsService {
  final Map<String, List<UtilityBillPayment>> _paymentsByUser = {};

  List<UtilityBillPayment> getPayments(String userId) {
    return List.unmodifiable(_paymentsByUser[userId] ?? <UtilityBillPayment>[]);
  }

  UtilityBillPayment payBill({
    required String userId,
    required UtilityBillType billType,
    required String provider,
    required String accountOrMeter,
    required double amount,
  }) {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
    if (userId.isEmpty) {
      throw ArgumentError('UserId is required');
    }
    if (accountOrMeter.isEmpty) {
      throw ArgumentError('Account or meter is required');
    }

    final id = 'bill_${DateTime.now().millisecondsSinceEpoch}_$userId';

    // Simple rule: all valid requests succeed (mock service)
    final payment = UtilityBillPayment(
      paymentId: id,
      userId: userId,
      billType: billType,
      provider: provider,
      accountOrMeter: accountOrMeter,
      amount: amount,
      timestamp: DateTime.now(),
      status: UtilityBillStatus.success,
      reference: 'REF-${DateTime.now().millisecondsSinceEpoch}',
    );

    final list = _paymentsByUser.putIfAbsent(userId, () => <UtilityBillPayment>[]);
    list.insert(0, payment);
    return payment;
  }
}
