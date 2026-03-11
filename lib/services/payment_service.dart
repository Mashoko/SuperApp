import 'dart:convert';

import 'package:http/http.dart' as http;

/// Simple result model for Africom / SuperApp Pay payments
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? message;

  PaymentResult({
    required this.success,
    this.transactionId,
    this.message,
  });
}

/// Africom - SuperApp Pay integration wrapper.
///
/// NOTE: The actual payment API endpoint is a placeholder and should be
/// aligned with the real backend implementation. The Integration ID / Key
/// and metadata are wired in here so the rest of the app can remain stable
/// when the backend is ready.
class AfricomPaymentService {
  // Provided integration metadata
  static const String _company = 'Africom';
  static const String _paymentLinkName = 'SuperApp Pay';
  static const String _integrationId = '23497';
  static const String _integrationKey =
      '797f55bd-1c31-4929-9a41-29f937dc974c';

  // Replace this with the real SuperApp Pay backend endpoint when available.
  // It is structured as an Africom SuperApp Pay route for clarity.
  static const String _paymentEndpoint =
      'https://superapp-diht.onrender.com/api/payments/africom/superapp-pay';

  const AfricomPaymentService();

  /// Initiates a payment with Africom SuperApp Pay.
  ///
  /// [amount]   - amount to charge (in the given [currency])
  /// [currency] - ISO currency code, e.g. "USD"
  /// [reference]- client-side reference for reconciliation
  /// [userId]   - current app user identifier
  /// [channel]  - channel label ("card", "ewallet", "ecocash", etc.)
  Future<PaymentResult> pay({
    required double amount,
    required String currency,
    required String reference,
    required String userId,
    required String channel,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_paymentEndpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-Integration-Id': _integrationId,
          'X-Integration-Key': _integrationKey,
        },
        body: jsonEncode(<String, dynamic>{
          'amount': amount,
          'currency': currency,
          'reference': reference,
          'user_id': userId,
          'company': _company,
          'payment_link': _paymentLinkName,
          'channel': channel,
        }),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        final bool success =
            (decoded is Map && (decoded['status'] == 'success' || decoded['paid'] == true));

        return PaymentResult(
          success: success,
          transactionId: decoded is Map && decoded['transaction_id'] != null
              ? decoded['transaction_id'].toString()
              : null,
          message: decoded is Map && decoded['message'] != null
              ? decoded['message'].toString()
              : null,
        );
      } else {
        return PaymentResult(
          success: false,
          message: 'Payment failed with status code ${response.statusCode}',
        );
      }
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Payment error: $e',
      );
    }
  }
}

