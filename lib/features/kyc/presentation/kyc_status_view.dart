import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/kyc_models.dart';
import 'kyc_form_view.dart';
import 'kyc_labels.dart';
import 'kyc_notifications_view.dart';
import 'kyc_status_controller.dart';
import 'kyc_theme.dart';

/// The user's verification status. The status label is the primary element;
/// "Continue verification" is the only primary action.
class KycStatusView extends StatefulWidget {
  const KycStatusView({super.key});

  @override
  State<KycStatusView> createState() => _KycStatusViewState();
}

class _KycStatusViewState extends State<KycStatusView> {
  @override
  void initState() {
    super.initState();
    // After the first frame so listeners elsewhere are not rebuilt mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<KycStatusController>().refresh());
    });
  }

  Future<void> _openForm() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<bool>(builder: (_) => const KycFormView()));
    if (!mounted) return;
    unawaited(context.read<KycStatusController>().refresh());
  }

  void _openUpdates() {
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const KycNotificationsView()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KycStatusController>();
    final theme = kycTheme(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(title: const Text('Verification')),
        body: Builder(builder: (context) => _body(context, controller)),
      ),
    );
  }

  Widget _body(BuildContext context, KycStatusController controller) {
    final status = controller.status;
    if (status == null) {
      if (controller.error != null) {
        return KycMessage(
          icon: Icons.cloud_off_outlined,
          text: controller.error!,
          action: FilledButton(
            onPressed: () => unawaited(controller.refresh()),
            child: const Text('Try again'),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          KycConstrained(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.error != null) ...[
                  KycNotice(text: controller.error!),
                  const SizedBox(height: 16),
                ],
                if (status.launched)
                  ..._launched(context, status)
                else
                  Text('Verification is not open yet.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 24, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _launched(BuildContext context, KycStatus status) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyLarge
        ?.copyWith(fontSize: 16, color: scheme.onSurfaceVariant);
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16);
    final deadline = status.deadline;
    final showDeadline =
        deadline != null && !status.isVerified && !status.isPendingReview;
    final note = switch (status.underlyingStatus) {
      'REJECTED' => status.rejectionReason,
      'REQUIRES_CORRECTION' => status.correctionNotes,
      _ => null,
    };
    final progress = status.progress.clamp(0, 100);

    return [
      Text('Status', style: muted),
      const SizedBox(height: 4),
      Text(
        kycStatusLabel(status.status),
        style: theme.textTheme.headlineMedium
            ?.copyWith(fontSize: 32, fontWeight: FontWeight.w600),
      ),
      if (showDeadline) ...[
        const SizedBox(height: 8),
        Text('Complete by ${kycLocalDate(deadline)}', style: body),
      ],
      const SizedBox(height: 24),
      Semantics(
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
      ),
      if (note != null) ...[
        const SizedBox(height: 24),
        const _Heading('Reviewer note'),
        const SizedBox(height: 8),
        _Bordered(child: Text(note, style: body)),
      ],
      if (status.outstanding.isNotEmpty) ...[
        const SizedBox(height: 24),
        const _Heading('Still needed'),
        const SizedBox(height: 4),
        for (final key in status.outstanding)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_box_outline_blank,
                    size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(kycFieldLabel(key), style: body)),
              ],
            ),
          ),
      ],
      if (status.canEdit) ...[
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _openForm,
          child: const Text('Continue verification'),
        ),
      ],
      const SizedBox(height: 16),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: _openUpdates,
          child: const Text('Updates'),
        ),
      ),
      if (status.history.isNotEmpty) ...[
        const SizedBox(height: 24),
        const _Heading('Submissions'),
        const SizedBox(height: 8),
        for (final entry in status.history) ...[
          _HistoryEntry(entry: entry),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
      );
}

class _Bordered extends StatelessWidget {
  const _Bordered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry});

  final KycHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16);
    final muted = body?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final submitted = entry.submittedAt;
    final decided = entry.decidedAt;
    return _Bordered(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submission ${entry.version}',
              style: body?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(kycDecisionLabel(entry.decision), style: body),
          if (submitted != null)
            Text('Sent ${kycLocalDate(submitted)}', style: muted),
          if (decided != null)
            Text('Decided ${kycLocalDate(decided)}', style: muted),
          if (entry.reason != null) ...[
            const SizedBox(height: 4),
            Text(entry.reason!, style: body),
          ],
        ],
      ),
    );
  }
}
