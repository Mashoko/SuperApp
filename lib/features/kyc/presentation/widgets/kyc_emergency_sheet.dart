import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/inject.dart';
import '../../../call/presentation/viewmodels/call_viewmodel.dart';
import '../../domain/emergency_numbers.dart';
import '../kyc_theme.dart';

/// Opens a URL such as `tel:999` outside the app. Returns false when it could
/// not be opened.
typedef KycDialerLauncher = Future<bool> Function(Uri uri);

// Called directly, without canLaunchUrl first: canLaunchUrl returns false on
// Android 11+ unless the manifest declares a DIAL query.
Future<bool> _launchExternally(Uri uri) => launchUrl(uri);

/// Opens the emergency numbers sheet. Tapping a number closes the sheet and
/// places a voice call through the app's normal call path, which always
/// allows emergency numbers (see `kycCallBlockReason`).
///
/// If the call cannot be started, a dialog on [context]'s navigator offers
/// the phone's own dialer through [launchDialer] (defaults to url_launcher).
/// Completes once the attempt is over, so callers can ignore repeat taps
/// until then.
Future<void> showKycEmergencySheet(BuildContext context,
    {KycDialerLauncher? launchDialer}) async {
  final number = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
    builder: (_) => const KycEmergencySheet(),
  );
  if (number == null) return;
  final error = await getIt<CallViewModel>().makeCall(number, voiceOnly: true);
  if (error == null || !context.mounted) return;
  await showEmergencyCallFailedDialog(context, number,
      launchDialer: launchDialer);
}

/// Shows [KycCallNotStartedDialog] for [number] on [context]'s nearest
/// navigator (not the root one), offering the phone's own dialer through
/// [launchDialer] (defaults to url_launcher). Tapping outside does not close
/// it. Completes when it closes.
Future<void> showEmergencyCallFailedDialog(
  BuildContext context,
  String number, {
  KycDialerLauncher? launchDialer,
}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (_) => KycCallNotStartedDialog(
        number: number,
        launchDialer: launchDialer ?? _launchExternally,
      ),
    );

/// Shown when an emergency call could not be started. Stays open until the
/// user closes it or the dialer opens.
class KycCallNotStartedDialog extends StatefulWidget {
  const KycCallNotStartedDialog({
    super.key,
    required this.number,
    required this.launchDialer,
  });

  final String number;
  final KycDialerLauncher launchDialer;

  @override
  State<KycCallNotStartedDialog> createState() =>
      _KycCallNotStartedDialogState();
}

class _KycCallNotStartedDialogState extends State<KycCallNotStartedDialog> {
  bool _dialerFailed = false;

  Future<void> _openDialer() async {
    var opened = false;
    try {
      opened = await widget.launchDialer(
          Uri(scheme: 'tel', path: widget.number));
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dialerFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge
        ?.copyWith(fontSize: 16, color: scheme.onSurface);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Call not started'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We could not start the call. '
            "Use your phone's dialer to call ${widget.number}.",
            style: body,
          ),
          if (_dialerFailed) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text('Dial ${widget.number} on your phone.', style: body),
            ),
            const SizedBox(height: 4),
            SelectableText(
              widget.number,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _openDialer,
          child: const Text('Open phone dialer'),
        ),
      ],
    );
  }
}

/// The emergency numbers as large rows. Pops with the chosen number; taps
/// after the first are ignored so a double tap cannot pop twice.
///
/// Numbers only. [CONFIRM WITH COMPLIANCE] before adding service names
/// (police, ambulance, fire) next to them.
class KycEmergencySheet extends StatefulWidget {
  const KycEmergencySheet({super.key});

  @override
  State<KycEmergencySheet> createState() => _KycEmergencySheetState();
}

class _KycEmergencySheetState extends State<KycEmergencySheet> {
  bool _picked = false;

  void _pick(String number) {
    if (_picked) return;
    _picked = true;
    Navigator.of(context).pop(number);
  }

  @override
  Widget build(BuildContext context) {
    final theme = kycTheme(Theme.of(context));
    final scheme = theme.colorScheme;
    final numberStyle = theme.textTheme.headlineSmall?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Theme(
      data: theme,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Call emergency services',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: 12),
              for (final number in kEmergencyNumbers)
                Semantics(
                  button: true,
                  label: 'Call $number',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _pick(number),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: scheme.outlineVariant)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.call_outlined, color: scheme.primary),
                          const SizedBox(width: 16),
                          Expanded(child: Text(number, style: numberStyle)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
