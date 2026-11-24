import 'package:flutter/material.dart';

const kycMaxContentWidth = 640.0;

/// Error text in the KYC screens is 14 px, so it needs 4.5:1 on the surface.
/// The app's error red (0xFFD32F2F) is only 3.3:1 on the dark surface; fall
/// back to Material 3's baseline error tone for that brightness.
Color _readableError(ColorScheme s) {
  final fg = s.error.computeLuminance(), bg = s.surface.computeLuminance();
  final ratio = (fg > bg ? fg + 0.05 : bg + 0.05) / (fg > bg ? bg + 0.05 : fg + 0.05);
  if (ratio >= 4.5) return s.error;
  return s.brightness == Brightness.dark
      ? const Color(0xFFFFB4AB)
      : const Color(0xFFB3261E);
}

/// Local theme for the KYC screens: one flat accent, hairline borders,
/// 8 px radius on buttons and 6 px on inputs, 16 px text and 48 px targets.
ThemeData kycTheme(ThemeData base) {
  final scheme =
      base.colorScheme.copyWith(error: _readableError(base.colorScheme));
  final inputRadius = BorderRadius.circular(6);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: inputRadius, borderSide: BorderSide(color: c, width: w));
  final buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  return base.copyWith(
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outline),
      disabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 2),
      labelStyle: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
      helperStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
      errorStyle: TextStyle(fontSize: 14, color: scheme.error),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(96, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: buttonShape,
        textStyle: textStyle,
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: buttonShape,
        textStyle: textStyle,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        shape: WidgetStatePropertyAll(buttonShape),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 16)),
      ),
    ),
  );
}

/// Centres content and caps its width for tablets and desktop.
class KycConstrained extends StatelessWidget {
  const KycConstrained({super.key, required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  // heightFactor 1: centre horizontally only. Without it, a bounded parent
  // (such as Scaffold.bottomNavigationBar) makes this fill the full height.
  Widget build(BuildContext context) => Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kycMaxContentWidth),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// A quiet bordered notice with an info icon.
class KycNotice extends StatelessWidget {
  const KycNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A centred full-screen message with one action.
class KycMessage extends StatelessWidget {
  const KycMessage({
    super.key,
    required this.icon,
    required this.text,
    required this.action,
    this.title,
  });

  final IconData icon;
  final String? title;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              if (title != null) ...[
                Text(title!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
              ],
              Text(text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18)),
              const SizedBox(height: 24),
              action,
            ],
          ),
        ),
      ),
    );
  }
}
