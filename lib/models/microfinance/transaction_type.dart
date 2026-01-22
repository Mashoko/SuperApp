enum TransactionType {
  loanDisbursement,
  loanRepayment,
  payment,
  deposit,
  withdrawal,
}

extension TransactionTypeExtension on TransactionType {
  String get value {
    switch (this) {
      case TransactionType.loanDisbursement:
        return 'loan_disbursement';
      case TransactionType.loanRepayment:
        return 'loan_repayment';
      case TransactionType.payment:
        return 'payment';
      case TransactionType.deposit:
        return 'deposit';
      case TransactionType.withdrawal:
        return 'withdrawal';
    }
  }

  static TransactionType fromString(String value) {
    switch (value) {
      case 'loan_disbursement':
        return TransactionType.loanDisbursement;
      case 'loan_repayment':
        return TransactionType.loanRepayment;
      case 'payment':
        return TransactionType.payment;
      case 'deposit':
        return TransactionType.deposit;
      case 'withdrawal':
        return TransactionType.withdrawal;
      default:
        return TransactionType.deposit;
    }
  }
}

