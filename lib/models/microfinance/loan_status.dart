enum LoanStatus {
  pending,
  approved,
  disbursed,
  active,
  completed,
  defaulted,
  rejected,
}

extension LoanStatusExtension on LoanStatus {
  String get value {
    switch (this) {
      case LoanStatus.pending:
        return 'pending';
      case LoanStatus.approved:
        return 'approved';
      case LoanStatus.disbursed:
        return 'disbursed';
      case LoanStatus.active:
        return 'active';
      case LoanStatus.completed:
        return 'completed';
      case LoanStatus.defaulted:
        return 'defaulted';
      case LoanStatus.rejected:
        return 'rejected';
    }
  }

  static LoanStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return LoanStatus.pending;
      case 'approved':
        return LoanStatus.approved;
      case 'disbursed':
        return LoanStatus.disbursed;
      case 'active':
        return LoanStatus.active;
      case 'completed':
        return LoanStatus.completed;
      case 'defaulted':
        return LoanStatus.defaulted;
      case 'rejected':
        return LoanStatus.rejected;
      default:
        return LoanStatus.pending;
    }
  }
}

