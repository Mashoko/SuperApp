import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'kyc_labels.dart';
import 'kyc_status_controller.dart';
import 'kyc_theme.dart';
import 'widgets/kyc_emergency_sheet.dart';

/// Full-screen, non-dismissible KYC screen shown by `KycGate` while the
/// account is restricted. "Complete KYC now" is the only primary action.
class MandatoryKycView extends StatelessWidget {
  const MandatoryKycView({
    super.key,
    required this.onCompleteNow,
    required this.onContactSupport,
    required this.onSignOut,
    this.launchDialer,
  });

  final VoidCallback onCompleteNow;
  final VoidCallback onContactSupport;
  final VoidCallback onSignOut;

  /// For tests. See [showKycEmergencySheet].
  final KycDialerLauncher? launchDialer;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KycStatusController>();
    final theme = kycTheme(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Builder(builder: (context) => _body(context, controller)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, KycStatusController controller) {
    final status = controller.status;
    if (status == null && controller.error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16);
    final muted = body?.copyWith(color: scheme.onSurfaceVariant);
    final progress = (status?.progress ?? 0).clamp(0, 100);
    final outstanding = status?.outstanding ?? const <String>[];

    return ListView(
      children: [
        KycConstrained(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Complete your KYC verification',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account needs verification to keep using calls, '
                'shopping, payments and posts.',
                style: body,
              ),
              const SizedBox(height: 8),
              Text(
                'POTRAZ requires us to confirm who owns each number. '
                'Emergency calls still work.',
                style: body,
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 16),
                KycNotice(text: controller.error!),
              ],
              if (status == null) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => unawaited(controller.refresh()),
                  child: const Text('Try again'),
                ),
              ] else ...[
                const SizedBox(height: 24),
                _Progress(progress: progress),
                if (outstanding.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text('Still needed',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  for (final key in outstanding)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_box_outline_blank,
                              size: 20, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(kycFieldLabel(key), style: body)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text('About 5 minutes', style: muted)),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onCompleteNow,
                  child: const Text('Complete KYC now'),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  _EmergencyCallButton(launchDialer: launchDialer),
                  TextButton(
                    onPressed: onContactSupport,
                    child: const Text('Contact support'),
                  ),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the emergency sheet. Disabled from the tap until the call attempt
/// is over, so repeat taps cannot open a second sheet or place a second call.
class _EmergencyCallButton extends StatefulWidget {
  const _EmergencyCallButton({this.launchDialer});

  final KycDialerLauncher? launchDialer;

  @override
  State<_EmergencyCallButton> createState() => _EmergencyCallButtonState();
}

class _EmergencyCallButtonState extends State<_EmergencyCallButton> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await showKycEmergencySheet(context, launchDialer: widget.launchDialer);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: _busy ? null : () => unawaited(_start()),
        icon: const Icon(Icons.call_outlined),
        label: const Text('Emergency call'),
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16);
    return Semantics(
      label: 'Progress',
      value: '$progress%',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Progress', style: body)),
                Text('$progress%',
                    style: body?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
