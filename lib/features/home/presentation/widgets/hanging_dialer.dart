import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class HangingDialerButton extends StatelessWidget {
  final VoidCallback onTap;

  const HangingDialerButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WunzaColors.glideAccent,
          boxShadow: [
            BoxShadow(
              color: WunzaColors.glideAccent.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.dialpad,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
