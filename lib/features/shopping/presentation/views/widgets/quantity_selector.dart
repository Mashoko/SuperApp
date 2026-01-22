import 'package:flutter/material.dart';


class QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double size;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(Icons.remove, onDecrement),
        Container(
          width: size * 1.5,
          alignment: Alignment.center,
          child: Text(
            '$quantity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        _buildButton(Icons.add, onIncrement),
      ],
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[200], // Grey background
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: Colors.black,
        ),
      ),
    );
  }
}
