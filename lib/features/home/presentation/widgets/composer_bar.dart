import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class ComposerBar extends StatelessWidget {
  const ComposerBar({super.key, required this.userInitials, required this.onTap});

  final String userInitials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: WunzaColors.navIndicator.withValues(alpha: 0.18),
              child: Text(userInitials,
                  style: TextStyle(
                      color: WunzaColors.navIndicator, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Share something...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
            ),
            Icon(Icons.image_outlined, color: Theme.of(context).hintColor, size: 20),
            const SizedBox(width: 8),
            Icon(Icons.videocam_outlined, color: Theme.of(context).hintColor, size: 20),
            const SizedBox(width: 8),
            Icon(Icons.mic_outlined, color: Theme.of(context).hintColor, size: 20),
          ],
        ),
      ),
    );
  }
}
