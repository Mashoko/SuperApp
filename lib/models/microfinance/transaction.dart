import 'package:mvvm_sip_demo/models/microfinance/transaction_type.dart';

class Transaction {
  final String transactionId;
  final String userId;
  final TransactionType transactionType;
  final double amount;
  final String description;
  final DateTime timestamp;

  Transaction({
    required this.transactionId,
    required this.userId,
    required this.transactionType,
    required this.amount,
    this.description = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'user_id': userId,
      'transaction_type': transactionType.value,
      'amount': amount,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      transactionId: json['transaction_id'] ?? '',
      userId: json['user_id'] ?? '',
      transactionType:
          TransactionTypeExtension.fromString(json['transaction_type'] ?? ''),
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : null,
    );
  }
}

