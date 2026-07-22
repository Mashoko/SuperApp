import 'package:flutter/material.dart';

class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

class FaqCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<FaqItem> items;
  const FaqCategory({required this.title, required this.icon, required this.color, required this.items});
}

const faqData = [
  FaqCategory(title: 'Payments', icon: Icons.payment_outlined, color: Color(0xFF185FA5), items: [
    FaqItem('Why is my payment pending?', 'Payments can take up to 24 hours to process depending on your bank or mobile money provider. If it has been longer than 24 hours, please use the Report a Problem form and attach your transaction receipt.'),
    FaqItem('My payment failed — what now?', 'Check that your card or wallet has sufficient funds and that your payment method is active. Try again or use an alternative method. If the issue persists, tap Report a Problem.'),
    FaqItem('I was charged twice', 'Duplicate charges are reversed automatically within 2 business days. If you have not received a refund after 3 days, contact our support team with the duplicate transaction IDs.'),
    FaqItem('What is the refund policy?', 'Digital services (calls, airtime) are non-refundable once delivered. Shopping orders can be refunded within 7 days of delivery if the item is unused and in original condition.'),
    FaqItem('My card was declined', 'Ensure your card is enabled for online payments. Some cards block international or digital transactions by default — contact your bank to enable them.'),
    FaqItem('What are the transaction limits?', 'Daily limits vary by payment method. EcoCash: \$500/day. Bank cards: \$2,000/day. Wallet transfers: \$1,000/day. Contact support to request a limit increase.'),
  ]),
  FaqCategory(title: 'Shopping', icon: Icons.shopping_bag_outlined, color: Color(0xFF9C27B0), items: [
    FaqItem('How do I track my order?', 'Go to Profile → My Orders and tap on your order. You will see the real-time status and estimated delivery date.'),
    FaqItem('My order has not arrived', 'Check the tracking status in My Orders. If the delivery window has passed, tap Report a Problem and select Shopping to raise an investigation.'),
    FaqItem('How do I return an item?', 'Visit My Orders, tap the order, and select Return Item. Returns must be requested within 7 days of delivery. The seller will arrange collection.'),
    FaqItem('Can I cancel my order?', 'Orders can be cancelled within 30 minutes of placement before they are confirmed by the seller. Go to My Orders → Cancel Order.'),
    FaqItem('I received the wrong item', 'Take a photo of the received item and tap Report a Problem → Shopping → Wrong Item Received. We will arrange a replacement or refund.'),
    FaqItem('Where is my refund?', 'Approved refunds are processed within 3–5 business days back to your original payment method.'),
  ]),
  FaqCategory(title: 'Calling & Airtime', icon: Icons.call_outlined, color: Color(0xFF00BCD4), items: [
    FaqItem('How do I buy airtime?', 'Tap the Calling tab → Buy Airtime, enter the amount and recipient number, then confirm payment.'),
    FaqItem('I sent airtime to the wrong number', 'Airtime transfers are instant and cannot be reversed. Please double-check the number before confirming a transfer.'),
    FaqItem('Poor call quality', 'VoIP call quality depends on your internet connection. For best results use Wi-Fi or a strong 4G signal. Try toggling airplane mode to reset your connection.'),
    FaqItem('My calls are dropping', 'Check your internet speed (minimum 1 Mbps for calls). If the issue persists, go to Account Services and re-register your SIP account.'),
    FaqItem('International calls not connecting', 'Ensure your account has sufficient balance and that the destination number is formatted correctly with the country code (e.g. +44 for UK).'),
    FaqItem('I was not credited after recharge', 'Wait 5 minutes and pull-to-refresh your balance. If the credit still has not appeared, report the issue with your voucher PIN and transaction reference.'),
  ]),
  FaqCategory(title: 'Wallet', icon: Icons.account_balance_wallet_outlined, color: Color(0xFF4CAF50), items: [
    FaqItem('How do I deposit into my wallet?', 'Tap Payment Methods → Add Funds and choose EcoCash, OneMoney, or bank transfer. Deposits reflect within minutes.'),
    FaqItem('How do I withdraw from my wallet?', 'Tap Wallet → Withdraw and select your bank account or mobile money number. Withdrawals take 1–2 business days.'),
    FaqItem('My wallet balance is incorrect', 'Pull down to refresh your wallet. If the balance is still wrong after refreshing, contact support with the specific transaction ID.'),
    FaqItem('Can I send money to another user?', 'Wallet transfers between app users are instant. Tap Wallet → Transfer and enter the recipient\'s phone number.'),
    FaqItem('What are the wallet limits?', 'The daily spending limit is \$2,000 and the wallet balance cap is \$5,000. Contact support to request an increase.'),
    FaqItem('Why is my wallet frozen?', 'Wallets are temporarily frozen after suspicious activity is detected. Tap Emergency → Unfreeze Account or contact support directly.'),
  ]),
  FaqCategory(title: 'Utility Bills', icon: Icons.bolt_outlined, color: Color(0xFFFF9800), items: [
    FaqItem('How do I pay ZESA?', 'Tap Bills → Electricity → ZESA, enter your meter number and amount, then confirm payment. The token is delivered by SMS.'),
    FaqItem('I paid but did not receive my ZESA token', 'Tokens are usually delivered within 2 minutes. Check your SMS inbox. If not received after 10 minutes, tap Report a Problem → Utility Bills.'),
    FaqItem('Can I pay bills for someone else?', 'Yes. During payment, enter the recipient\'s account number or meter number instead of your own.'),
    FaqItem('Which utility providers are supported?', 'ZESA, ZINWA, DSTV, ZOL, TelOne, NetOne, Econet, Municipality rates, and selected school fees.'),
    FaqItem('My bill payment is pending', 'Some payments to utility providers take up to 30 minutes to process. If it is pending for more than 1 hour, report the issue with your reference number.'),
    FaqItem('Can I set up recurring bill payments?', 'Recurring payments are coming soon. You will be notified when the feature is available.'),
  ]),
  FaqCategory(title: 'Account & Security', icon: Icons.security_outlined, color: Color(0xFFE53935), items: [
    FaqItem('How do I reset my PIN?', 'Tap Profile → Account Services → Reset PIN. You will receive an OTP on your registered phone number to verify your identity.'),
    FaqItem('How do I change my phone number?', 'Phone number changes require identity verification. Contact support with a copy of your ID and proof of ownership of the new number.'),
    FaqItem('I cannot log in to my account', 'Tap Forgot Password on the login screen to reset via OTP. If you no longer have access to your registered number, contact support immediately.'),
    FaqItem('How do I enable two-factor authentication?', 'Go to Profile → Settings → Security → Two-Factor Authentication and follow the setup steps.'),
    FaqItem('I suspect unauthorized access to my account', 'Immediately tap Emergency → Account Compromised. This will lock your account and alert our security team.'),
    FaqItem('How do I delete my account?', 'Account deletion requests must be submitted in writing to support@firststreet.co.zw with your full name and registered phone number.'),
  ]),
  FaqCategory(title: 'General', icon: Icons.help_outline, color: Color(0xFF607D8B), items: [
    FaqItem('What is First Street?', 'First Street is a super app providing calling, shopping, utility bill payments, and wallet services across Zimbabwe and the region.'),
    FaqItem('Is my data secure?', 'Yes. All data is encrypted in transit and at rest. We comply with applicable data protection regulations and never sell your personal information.'),
    FaqItem('How do I update the app?', 'Open the Google Play Store or Apple App Store and search for First Street to download the latest version.'),
    FaqItem('The app is crashing', 'Try force-closing and reopening the app. If the issue continues, uninstall and reinstall from the store. If it still crashes, report the issue.'),
    FaqItem('How do I contact support?', 'Use any channel on the Help & Support screen: WhatsApp, live chat, email, or phone. WhatsApp is the fastest.'),
    FaqItem('What are support hours?', 'WhatsApp and chat: 24/7. Phone support: Monday–Friday 08:00–17:00 CAT. Email: responses within 24 hours.'),
  ]),
];
