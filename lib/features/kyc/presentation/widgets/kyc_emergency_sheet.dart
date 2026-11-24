import 'package:flutter/material.dart';

import '../../../../core/di/inject.dart';
import '../../../call/presentation/viewmodels/call_viewmodel.dart';
import '../../domain/emergency_numbers.dart';
import '../kyc_theme.dart';

/// Opens the emergency numbers sheet. Tapping a number closes the sheet and
/// places a voice call through the app's normal call path, which always
/// allows emergency numbers (see `kycCallBlockReason`).
Future<void> showKycEmergencySheet(BuildContext context) async {
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
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(error)));
}

/// The emergency numbers as large rows. Pops with the chosen number.
///
/// Numbers only. [CONFIRM WITH COMPLIANCE] before adding service names
/// (police, ambulance, fire) next to them.
class KycEmergencySheet extends StatelessWidget {
  const KycEmergencySheet({super.key});

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
                    onTap: () => Navigator.of(context).pop(number),
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
