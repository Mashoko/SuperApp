const faqSeedData = [
  {
    title: 'Payments',
    items: [
      { question: 'Why is my payment pending?', answer: 'Payments can take up to 24 hours to process depending on your bank or mobile money provider. If it has been longer than 24 hours, please use the Report a Problem form and attach your transaction receipt.' },
      { question: 'My payment failed — what now?', answer: 'Check that your card or wallet has sufficient funds and that your payment method is active. Try again or use an alternative method. If the issue persists, tap Report a Problem.' },
      { question: 'I was charged twice', answer: 'Duplicate charges are reversed automatically within 2 business days. If you have not received a refund after 3 days, contact our support team with the duplicate transaction IDs.' },
      { question: 'What is the refund policy?', answer: 'Digital services (calls, airtime) are non-refundable once delivered. Shopping orders can be refunded within 7 days of delivery if the item is unused and in original condition.' },
      { question: 'My card was declined', answer: 'Ensure your card is enabled for online payments. Some cards block international or digital transactions by default — contact your bank to enable them.' },
      { question: 'What are the transaction limits?', answer: 'Daily limits vary by payment method. EcoCash: $500/day. Bank cards: $2,000/day. Wallet transfers: $1,000/day. Contact support to request a limit increase.' },
    ],
  },
  {
    title: 'Shopping',
    items: [
      { question: 'How do I track my order?', answer: 'Go to Profile → My Orders and tap on your order. You will see the real-time status and estimated delivery date.' },
      { question: 'My order has not arrived', answer: 'Check the tracking status in My Orders. If the delivery window has passed, tap Report a Problem and select Shopping to raise an investigation.' },
      { question: 'How do I return an item?', answer: 'Visit My Orders, tap the order, and select Return Item. Returns must be requested within 7 days of delivery. The seller will arrange collection.' },
      { question: 'Can I cancel my order?', answer: 'Orders can be cancelled within 30 minutes of placement before they are confirmed by the seller. Go to My Orders → Cancel Order.' },
      { question: 'I received the wrong item', answer: 'Take a photo of the received item and tap Report a Problem → Shopping → Wrong Item Received. We will arrange a replacement or refund.' },
      { question: 'Where is my refund?', answer: 'Approved refunds are processed within 3–5 business days back to your original payment method.' },
    ],
  },
  {
    title: 'Calling & Airtime',
    items: [
      { question: 'How do I buy airtime?', answer: 'Tap the Calling tab → Buy Airtime, enter the amount and recipient number, then confirm payment.' },
      { question: 'I sent airtime to the wrong number', answer: 'Airtime transfers are instant and cannot be reversed. Please double-check the number before confirming a transfer.' },
      { question: 'Poor call quality', answer: 'VoIP call quality depends on your internet connection. For best results use Wi-Fi or a strong 4G signal. Try toggling airplane mode to reset your connection.' },
      { question: 'My calls are dropping', answer: 'Check your internet speed (minimum 1 Mbps for calls). If the issue persists, go to Account Services and re-register your SIP account.' },
      { question: 'International calls not connecting', answer: 'Ensure your account has sufficient balance and that the destination number is formatted correctly with the country code (e.g. +44 for UK).' },
      { question: 'I was not credited after recharge', answer: 'Wait 5 minutes and pull-to-refresh your balance. If the credit still has not appeared, report the issue with your voucher PIN and transaction reference.' },
    ],
  },
  {
    title: 'Wallet',
    items: [
      { question: 'How do I deposit into my wallet?', answer: 'Tap Payment Methods → Add Funds and choose EcoCash, OneMoney, or bank transfer. Deposits reflect within minutes.' },
      { question: 'How do I withdraw from my wallet?', answer: 'Tap Wallet → Withdraw and select your bank account or mobile money number. Withdrawals take 1–2 business days.' },
      { question: 'My wallet balance is incorrect', answer: 'Pull down to refresh your wallet. If the balance is still wrong after refreshing, contact support with the specific transaction ID.' },
      { question: 'Can I send money to another user?', answer: 'Wallet transfers between app users are instant. Tap Wallet → Transfer and enter the recipient\'s phone number.' },
      { question: 'What are the wallet limits?', answer: 'The daily spending limit is $2,000 and the wallet balance cap is $5,000. Contact support to request an increase.' },
      { question: 'Why is my wallet frozen?', answer: 'Wallets are temporarily frozen after suspicious activity is detected. Tap Emergency → Unfreeze Account or contact support directly.' },
    ],
  },
  {
    title: 'Utility Bills',
    items: [
      { question: 'How do I pay ZESA?', answer: 'Tap Bills → Electricity → ZESA, enter your meter number and amount, then confirm payment. The token is delivered by SMS.' },
      { question: 'I paid but did not receive my ZESA token', answer: 'Tokens are usually delivered within 2 minutes. Check your SMS inbox. If not received after 10 minutes, tap Report a Problem → Utility Bills.' },
      { question: 'Can I pay bills for someone else?', answer: 'Yes. During payment, enter the recipient\'s account number or meter number instead of your own.' },
      { question: 'Which utility providers are supported?', answer: 'ZESA, ZINWA, DSTV, ZOL, TelOne, NetOne, Econet, Municipality rates, and selected school fees.' },
      { question: 'My bill payment is pending', answer: 'Some payments to utility providers take up to 30 minutes to process. If it is pending for more than 1 hour, report the issue with your reference number.' },
      { question: 'Can I set up recurring bill payments?', answer: 'Recurring payments are coming soon. You will be notified when the feature is available.' },
    ],
  },
  {
    title: 'Account & Security',
    items: [
      { question: 'How do I reset my PIN?', answer: 'Tap Profile → Account Services → Reset PIN. You will receive an OTP on your registered phone number to verify your identity.' },
      { question: 'How do I change my phone number?', answer: 'Phone number changes require identity verification. Contact support with a copy of your ID and proof of ownership of the new number.' },
      { question: 'I cannot log in to my account', answer: 'Tap Forgot Password on the login screen to reset via OTP. If you no longer have access to your registered number, contact support immediately.' },
      { question: 'How do I enable two-factor authentication?', answer: 'Go to Profile → Settings → Security → Two-Factor Authentication and follow the setup steps.' },
      { question: 'I suspect unauthorized access to my account', answer: 'Immediately tap Emergency → Account Compromised. This will lock your account and alert our security team.' },
      { question: 'How do I delete my account?', answer: 'Account deletion requests must be submitted in writing to support@firststreet.co.zw with your full name and registered phone number.' },
    ],
  },
  {
    title: 'General',
    items: [
      { question: 'What is First Street?', answer: 'First Street is a super app providing calling, shopping, utility bill payments, and wallet services across Zimbabwe and the region.' },
      { question: 'Is my data secure?', answer: 'Yes. All data is encrypted in transit and at rest. We comply with applicable data protection regulations and never sell your personal information.' },
      { question: 'How do I update the app?', answer: 'Open the Google Play Store or Apple App Store and search for First Street to download the latest version.' },
      { question: 'The app is crashing', answer: 'Try force-closing and reopening the app. If the issue continues, uninstall and reinstall from the store. If it still crashes, report the issue.' },
      { question: 'How do I contact support?', answer: 'Use any channel on the Help & Support screen: WhatsApp, live chat, email, or phone. WhatsApp is the fastest.' },
      { question: 'What are support hours?', answer: 'WhatsApp and chat: 24/7. Phone support: Monday–Friday 08:00–17:00 CAT. Email: responses within 24 hours.' },
    ],
  },
];

module.exports = faqSeedData;
