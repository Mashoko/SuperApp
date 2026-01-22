import 'package:mvvm_sip_demo/models/microfinance/loan_status.dart';
import 'package:mvvm_sip_demo/models/microfinance/transaction.dart';

class Loan {
  final String loanId;
  final String userId;
  final double principalAmount;
  final double interestRate; // Annual interest rate
  final int tenureMonths;
  final String purpose;
  final LoanStatus status;
  final DateTime? approvedDate;
  final DateTime? disbursedDate;
  final double monthlyEmi;
  final double totalAmount;
  double remainingBalance;
  final List<Transaction> repayments;

  Loan({
    required this.loanId,
    required this.userId,
    required this.principalAmount,
    required this.interestRate,
    required this.tenureMonths,
    this.purpose = '',
    this.status = LoanStatus.pending,
    this.approvedDate,
    this.disbursedDate,
    required this.monthlyEmi,
    required this.totalAmount,
    double? remainingBalance,
    List<Transaction>? repayments,
  })  : remainingBalance = remainingBalance ?? principalAmount,
        repayments = repayments ?? [];

  static double _pow(double base, int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  static double calculateEmi(double principalAmount, double interestRate, int tenureMonths) {
    if (interestRate == 0) {
      return principalAmount / tenureMonths;
    }
    final monthlyRate = interestRate / 12 / 100;
    final emi = (principalAmount *
            monthlyRate *
            _pow(1 + monthlyRate, tenureMonths)) /
        (_pow(1 + monthlyRate, tenureMonths) - 1);
    return emi;
  }

  Map<String, dynamic> toJson() {
    return {
      'loan_id': loanId,
      'user_id': userId,
      'principal_amount': principalAmount,
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      'purpose': purpose,
      'status': status.value,
      'monthly_emi': monthlyEmi,
      'total_amount': totalAmount,
      'remaining_balance': remainingBalance,
      'approved_date': approvedDate?.toIso8601String(),
      'disbursed_date': disbursedDate?.toIso8601String(),
      'repayments_count': repayments.length,
    };
  }

  factory Loan.fromJson(Map<String, dynamic> json) {
    final principalAmount = (json['principal_amount'] ?? 0).toDouble();
    final interestRate = (json['interest_rate'] ?? 0).toDouble();
    final tenureMonths = json['tenure_months'] ?? 0;
    
    // Calculate EMI and total
    final monthlyEmi = calculateEmi(principalAmount, interestRate, tenureMonths);
    final totalAmount = monthlyEmi * tenureMonths;

    return Loan(
      loanId: json['loan_id'] ?? '',
      userId: json['user_id'] ?? '',
      principalAmount: principalAmount,
      interestRate: interestRate,
      tenureMonths: tenureMonths,
      purpose: json['purpose'] ?? '',
      status: LoanStatusExtension.fromString(json['status'] ?? 'pending'),
      monthlyEmi: (json['monthly_emi'] ?? monthlyEmi).toDouble(),
      totalAmount: (json['total_amount'] ?? totalAmount).toDouble(),
      remainingBalance: (json['remaining_balance'] ?? principalAmount).toDouble(),
      approvedDate: json['approved_date'] != null
          ? DateTime.parse(json['approved_date'])
          : null,
      disbursedDate: json['disbursed_date'] != null
          ? DateTime.parse(json['disbursed_date'])
          : null,
      repayments: (json['repayments'] as List<dynamic>?)
              ?.map((r) => Transaction.fromJson(r))
              .toList() ??
          [],
    );
  }
}

extension DoubleExtension on double {
  double pow(int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= this;
    }
    return result;
  }
}

