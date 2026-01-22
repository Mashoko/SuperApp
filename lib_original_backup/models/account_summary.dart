class AccountSummary {
  const AccountSummary({
    required this.username,
    required this.alias,
    required this.balance,
    required this.domain,
    required this.status,
    this.infoMessage,
  });

  final String username;
  final String alias;
  final double balance;
  final String domain;
  final String status;
  final String? infoMessage;

  String get formattedBalance {
    final prefix = balance < 0 ? '-\$' : '\$';
    final value = balance.abs().toStringAsFixed(2);
    return '$prefix$value';
  }
}

