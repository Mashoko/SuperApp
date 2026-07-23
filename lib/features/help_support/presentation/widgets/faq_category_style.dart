import 'package:flutter/material.dart';

const _fallbackStyle = (icon: Icons.help_outline, color: Color(0xFF607D8B));

const Map<String, ({IconData icon, Color color})> faqCategoryStyles = {
  'Payments': (icon: Icons.payment_outlined, color: Color(0xFF185FA5)),
  'Shopping': (icon: Icons.shopping_bag_outlined, color: Color(0xFF9C27B0)),
  'Calling & Airtime': (icon: Icons.call_outlined, color: Color(0xFF00BCD4)),
  'Wallet': (icon: Icons.account_balance_wallet_outlined, color: Color(0xFF4CAF50)),
  'Utility Bills': (icon: Icons.bolt_outlined, color: Color(0xFFFF9800)),
  'Account & Security': (icon: Icons.security_outlined, color: Color(0xFFE53935)),
  'General': (icon: Icons.help_outline, color: Color(0xFF607D8B)),
};

({IconData icon, Color color}) faqCategoryStyle(String title) =>
    faqCategoryStyles[title] ?? _fallbackStyle;
