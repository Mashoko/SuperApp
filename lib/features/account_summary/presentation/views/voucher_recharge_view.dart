import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/payments_client.dart';

class VoucherRechargeView extends StatefulWidget {
  const VoucherRechargeView({super.key});

  @override
  State<VoucherRechargeView> createState() => _VoucherRechargeViewState();
}

class _VoucherRechargeViewState extends State<VoucherRechargeView> {
  final _formKey = GlobalKey<FormState>();
  final _pinCtrl = TextEditingController();

  bool _loading = false;
  String? _resultMessage;
  bool _resultSuccess = false;
  double? _balanceAfter;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _resultMessage = null; _balanceAfter = null; });

    final creds = await getIt<OtpAuthService>().getStoredCredentials();
    if (creds == null || !mounted) {
      setState(() { _loading = false; _resultMessage = 'Not logged in.'; _resultSuccess = false; });
      return;
    }

    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
    final client = getIt<PaymentsClient>();
    final resp = await client.rechargeAccount(
      username: creds['username']!,
      password: creds['password']!,
      voucherPin: _pinCtrl.text.trim(),
      transactionId: transactionId,
    );

    if (!mounted) return;

    final ok = resp.status == Status.SUCCESSFUL || resp.status == Status.INFORMATION;
    setState(() {
      _loading = false;
      _resultSuccess = ok;
      _balanceAfter = ok && resp.balanceAfter > 0 ? resp.balanceAfter : null;
      _resultMessage = ok
          ? (resp.hasSuccess()
              ? resp.success.localizedDescription
              : 'Account recharged successfully.')
          : (resp.hasError()
              ? resp.error.localizedDescription
              : 'Failed to recharge. Check your voucher PIN and try again.');
      if (ok) _pinCtrl.clear();
    });
  }

  String _fmtMinutes(double minutes) {
    final total = minutes.round();
    if (total >= 60) {
      final h = total ~/ 60;
      final m = total % 60;
      return '$h hr${h > 1 ? 's' : ''} $m min';
    }
    return '$total min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFBD34D1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Voucher Recharge',
          style: TextStyle(color: Color(0xFFBD34D1), fontWeight: FontWeight.w400, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Icon header
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_number_outlined, size: 36, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter your voucher PIN to top up your account',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Form card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Voucher PIN',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pinCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: false,
                      decoration: InputDecoration(
                        hintText: 'Enter voucher PIN',
                        hintStyle: const TextStyle(color: Colors.black38),
                        prefixIcon: const Icon(Icons.pin_outlined, color: Colors.black38, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFBD34D1), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Voucher PIN is required';
                        if (v.trim().length < 4) return 'PIN must be at least 4 digits';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Result banner
            if (_resultMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_resultSuccess ? const Color(0xFF6C63FF) : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _resultSuccess ? const Color(0xFF6C63FF) : Colors.red,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _resultSuccess ? Icons.check_circle_outline : Icons.error_outline,
                          color: _resultSuccess ? const Color(0xFF6C63FF) : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _resultMessage!,
                            style: TextStyle(
                              color: _resultSuccess ? const Color(0xFF6C63FF) : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_balanceAfter != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Text(
                          'New balance: ${_fmtMinutes(_balanceAfter!)}',
                          style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Recharge Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
