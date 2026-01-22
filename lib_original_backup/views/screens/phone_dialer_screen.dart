import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/call_view_model.dart';
import '../widgets/dialer_keypad.dart';

class PhoneDialerScreen extends StatelessWidget {
  const PhoneDialerScreen({super.key});

  static Future<void> refreshBalances(BuildContext context) async {
    final callViewModel = context.read<CallViewModel>();
    final success = await callViewModel.refreshCachedAccount();
    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter account details first to refresh.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final callViewModel = context.watch<CallViewModel>();

    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            _DialDisplay(number: callViewModel.dialedNumber),
            const SizedBox(height: 12),
            Expanded(
              child: DialerKeypad(
                onTap: callViewModel.appendDialInput,
                onBackspace: callViewModel.removeLastDialInput,
              ),
            ),
            const SizedBox(height: 8),
            _DialActions(
              onCallPressed: callViewModel.placeCall,
              onClearPressed: callViewModel.clearDialInput,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DialDisplay extends StatelessWidget {
  const _DialDisplay({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number.isEmpty ? 'Enter number' : number,
          style: TextStyle(
            fontSize: number.isEmpty ? 18 : 28,
            fontWeight: FontWeight.w500,
            color: number.isEmpty ? Colors.black45 : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: Colors.black12),
      ],
    );
  }
}

class _DialActions extends StatelessWidget {
  const _DialActions({
    required this.onCallPressed,
    required this.onClearPressed,
  });

  final VoidCallback onCallPressed;
  final VoidCallback onClearPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onCallPressed,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.phone,
              size: 32,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onClearPressed,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

