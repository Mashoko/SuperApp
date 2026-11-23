import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../kyc_labels.dart';
import '../kyc_status_controller.dart';
import '../kyc_status_view.dart';
import '../kyc_theme.dart';

/// One-line verification prompt for the home screen. Renders nothing while
/// the status is unknown, before launch, when restricted (the gate covers the
/// app) and once the record is submitted or approved.
class KycBanner extends StatelessWidget {
  const KycBanner({super.key, this.margin = EdgeInsets.zero});

  /// Space around the banner, only applied when it is visible.
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KycStatusController>();
    final status = controller.status;
    if (status == null || !status.launched || controller.isRestricted) {
      return const SizedBox.shrink();
    }
    final deadline = status.deadline;
    final (String text, String action)? content = switch (status.status) {
      'NOT_STARTED' || 'IN_PROGRESS' => (
          deadline == null
              ? 'Verify your number.'
              : 'Verify your number before ${kycLocalDate(deadline)}.',
          'Continue'
        ),
      'REJECTED' || 'REQUIRES_CORRECTION' => (
          'Your KYC needs attention.',
          'Review'
        ),
      'EXPIRED' => ('Please renew your KYC.', 'Renew'),
      _ => null,
    };
    if (content == null) return const SizedBox.shrink();

    final theme = kycTheme(Theme.of(context));
    final scheme = theme.colorScheme;
    return Theme(
      data: theme,
      child: Padding(
        padding: margin,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(content.$1,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontSize: 16, color: scheme.onSurface)),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const KycStatusView())),
                child: Text(content.$2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
