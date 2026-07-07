import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

/// Respects reduced-motion: collapses to instant when the platform/user has
/// disabled animations (Flutter's equivalent of `prefers-reduced-motion`).
Duration _motionDuration(BuildContext context, Duration normal) {
  return MediaQuery.of(context).disableAnimations ? Duration.zero : normal;
}

/// One tab in [GlassBottomNav]. Exactly 4 tabs are supported — the PAD is
/// visually centered at the 50% mark, which only lines up between tabs 1
/// and 2 when there are 4 of them (matches the approved design).
class GlassNavTab {
  const GlassNavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// One quick action shown when the PAD is long-pressed.
class GlassNavQuickAction {
  const GlassNavQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class GlassBottomNav extends StatefulWidget {
  const GlassBottomNav({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onDialerTap,
    required this.quickActions,
    this.visible = true,
  });

  final List<GlassNavTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onDialerTap;
  final List<GlassNavQuickAction> quickActions;
  final bool visible;

  @override
  State<GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends State<GlassBottomNav> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor =
        isDark ? WunzaColors.navGlassDark : WunzaColors.navGlassLight;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.65);

    return AnimatedSlide(
      duration: _motionDuration(context, const Duration(milliseconds: 320)),
      curve: Curves.easeOutCubic,
      offset: widget.visible ? Offset.zero : const Offset(0, 1.6),
      child: SizedBox(
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 72,
              child: Container(
                decoration: BoxDecoration(
                  color: glassColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                    // LayoutBuilder wraps the Stack (not a Positioned) so it
                    // sits between two RenderObjects that both expect a plain
                    // box child — Positioned/AnimatedPositioned must be a
                    // direct Stack child with nothing else in between, and
                    // LayoutBuilder is itself backed by a RenderObject, so it
                    // cannot sit directly between a Stack and a Positioned.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            _SlidingIndicator(
                              activeIndex: widget.activeIndex,
                              tabCount: widget.tabs.length,
                              navWidth: constraints.maxWidth,
                            ),
                            Row(
                              children: [
                                for (var i = 0; i < widget.tabs.length; i++)
                                  Expanded(
                                    child: _GlassTabButton(
                                      tab: widget.tabs[i],
                                      isActive: i == widget.activeIndex,
                                      onTap: () => widget.onTabSelected(i),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        WunzaColors.padGradientStart,
                        WunzaColors.padGradientEnd,
                      ],
                    ),
                  ),
                  child: const Icon(Icons.dialpad,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain [StatelessWidget] (not backed by its own RenderObject) so its
/// [AnimatedPositioned] resolves directly against the ancestor [Stack] —
/// [navWidth] is measured by a [LayoutBuilder] one level up, in
/// [_GlassBottomNavState.build], rather than here.
class _SlidingIndicator extends StatelessWidget {
  const _SlidingIndicator({
    required this.activeIndex,
    required this.tabCount,
    required this.navWidth,
  });

  final int activeIndex;
  final int tabCount;
  final double navWidth;

  static const double _width = 28;

  @override
  Widget build(BuildContext context) {
    final slotWidth = navWidth / tabCount;
    final left = slotWidth * activeIndex + slotWidth / 2 - _width / 2;
    return AnimatedPositioned(
      key: const Key('glass-nav-indicator'),
      duration: _motionDuration(context, const Duration(milliseconds: 320)),
      curve: Curves.easeOutCubic,
      bottom: 8,
      left: left,
      child: Container(
        width: _width,
        height: 3,
        decoration: BoxDecoration(
          color: WunzaColors.navIndicator,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: WunzaColors.navIndicator.withValues(alpha: 0.6),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassTabButton extends StatelessWidget {
  const _GlassTabButton({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final GlassNavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final color = isActive ? onSurface : onSurface.withValues(alpha: 0.56);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: tab.label,
          selected: isActive,
          button: true,
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isActive ? 1.14 : 1.0,
                  duration: _motionDuration(context, const Duration(milliseconds: 300)),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isActive ? tab.activeIcon : tab.icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedOpacity(
                  opacity: isActive ? 1 : 0,
                  duration: _motionDuration(context, const Duration(milliseconds: 220)),
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
