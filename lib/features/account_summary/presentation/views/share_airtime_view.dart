import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/payments_client.dart';

class ShareAirtimeView extends StatefulWidget {
  const ShareAirtimeView({super.key});

  @override
  State<ShareAirtimeView> createState() => _ShareAirtimeViewState();
}

class _ShareAirtimeViewState extends State<ShareAirtimeView> {
  final _formKey = GlobalKey<FormState>();
  final _receiverCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  bool _loading = false;
  String? _resultMessage;
  bool _resultSuccess = false;
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _receiverCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _dismissTimer?.cancel();
    setState(() { _loading = true; _resultMessage = null; });

    final creds = await getIt<OtpAuthService>().getStoredCredentials();
    if (creds == null || !mounted) {
      setState(() { _loading = false; _resultMessage = 'Not logged in.'; _resultSuccess = false; });
      return;
    }

    final client = getIt<PaymentsClient>();
    final resp = await client.shareAirtime(
      username: creds['username']!,
      password: creds['password']!,
      receiver: _receiverCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
    );

    if (!mounted) return;

    final ok = resp.status == Status.SUCCESSFUL || resp.status == Status.INFORMATION;
    setState(() {
      _loading = false;
      _resultSuccess = ok;
      _resultMessage = ok
          ? (resp.hasSuccess()
              ? resp.success.localizedDescription
              : 'Airtime transfered successfuly, thank you for using our service.')
          : (resp.hasError()
              ? resp.error.localizedDescription
              : 'Failed to share airtime. Please try again.');
    });

    if (ok) {
      // Auto-dismiss success banner and reset fields after 3 seconds.
      _dismissTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() { _resultMessage = null; });
        _receiverCtrl.clear();
        _amountCtrl.clear();
        _formKey.currentState?.reset();
      });
    }
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
          'Share Airtime',
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
                color: const Color(0xFF00C853).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_to_mobile, size: 36, color: Color(0xFF00C853)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Send airtime to any CatchApp user',
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
                    const Text('Recipient',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _receiverCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('e.g. +263781234567', Icons.person_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Recipient number is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Amount (minutes)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration('e.g. 10', Icons.access_time_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Amount is required';
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Result banner
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _resultMessage != null
                  ? Container(
                      key: ValueKey(_resultMessage),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (_resultSuccess ? const Color(0xFF00C853) : Colors.red)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _resultSuccess ? const Color(0xFF00C853) : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _resultSuccess ? Icons.check_circle_outline : Icons.error_outline,
                            color: _resultSuccess ? const Color(0xFF00C853) : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _resultMessage!,
                              style: TextStyle(
                                color: _resultSuccess ? const Color(0xFF00C853) : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
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
                    : const Text('Send Airtime', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      prefixIcon: Icon(icon, color: Colors.black38, size: 20),
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
    );
  }
}
