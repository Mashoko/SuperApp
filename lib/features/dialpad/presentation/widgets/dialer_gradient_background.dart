import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

/// Full-bleed dark gradient background shared by the redesigned dialer and
/// (when its `darkTheme` flag is on) the contacts screen, so both read as
/// one continuous surface.
class DialerGradientBackground extends StatelessWidget {
  const DialerGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: WunzaColors.dialerBackgroundGradient,
      ),
      child: child,
    );
  }
}

/// Rounded translucent "glass" panel used to house the dialer keypad over
/// [DialerGradientBackground].
class GlassPanelContainer extends StatelessWidget {
  const GlassPanelContainer({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(20, 20, 20, 0),
  });

  final Widget child;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: WunzaColors.dialerPanelFill,
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
