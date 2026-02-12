import 'package:flutter/material.dart';

class HangingDialerButton extends StatelessWidget {
  final VoidCallback onTap;

  const HangingDialerButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, // Fixed size for the circle
        height: 64,
        decoration: BoxDecoration(
          // Gradient background for the circular shape
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2196F3), // Blue
              Color(0xFF1976D2), // Darker Blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.dialpad_outlined,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
