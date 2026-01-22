import 'package:flutter/material.dart';

class DialerKeypad extends StatelessWidget {
  const DialerKeypad({
    super.key,
    required this.onTap,
    required this.onBackspace,
  });

  final void Function(String value) onTap;
  final VoidCallback onBackspace;

  static const Map<String, String> _secondary = {
    '1': '',
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '*': '',
    '0': '+',
    '#': '',
  };

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: keys.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final label = keys[index];
                  final secondary = _secondary[label] ?? '';
                  return _DialerButton(
                    label: label,
                    secondary: secondary,
                    onPressed: () => onTap(label),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            IconButton(
              onPressed: onBackspace,
              icon: const Icon(Icons.backspace_outlined),
            ),
          ],
        );
      },
    );
  }
}

class _DialerButton extends StatelessWidget {
  const _DialerButton({
    required this.label,
    required this.secondary,
    required this.onPressed,
  });

  final String label;
  final String secondary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(60),
      onTap: onPressed,
      child: SizedBox(width: 90, height: 90, child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (secondary.isNotEmpty)
              Text(
                secondary,
                style: const TextStyle(
                  letterSpacing: 1.2,
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
