import 'dart:math' as math;
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
  OverlayEntry? _fanEntry;

  void _openFan() {
    if (_fanEntry != null || widget.quickActions.isEmpty) return;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: _QuickActionFan(
          actions: widget.quickActions,
          onDismiss: _closeFan,
        ),
      ),
    );
    overlay.insert(entry);
    _fanEntry = entry;
  }

  void _closeFan() {
    _fanEntry?.remove();
    _fanEntry = null;
  }

  void _onPadTap() {
    _closeFan();
    widget.onDialerTap();
  }

  @override
  void dispose() {
    _fanEntry?.remove();
    super.dispose();
  }

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
                child: GestureDetector(
                  key: const Key('glass-nav-pad'),
                  onTap: _onPadTap,
                  onLongPress: widget.quickActions.isEmpty ? null : _openFan,
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
                      boxShadow: [
                        BoxShadow(
                          color:
                              WunzaColors.padGradientEnd.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.dialpad,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen scrim + radially-arranged quick actions, shown via [Overlay]
/// so it can dim/dismiss over the whole screen regardless of where
/// [GlassBottomNav] itself is positioned.
class _QuickActionFan extends StatelessWidget {
  const _QuickActionFan({required this.actions, required this.onDismiss});

  final List<GlassNavQuickAction> actions;
  final VoidCallback onDismiss;

  static List<double> _anglesFor(int count) {
    if (count == 1) return const [-90];
    if (count == 2) return const [-130, -50];
    if (count == 3) return const [-150, -90, -30];
    return List.generate(
        count, (i) => -180 + (180 / (count + 1)) * (i + 1));
  }

  @override
  Widget build(BuildContext context) {
    final angles = _anglesFor(actions.length);
    const dist = 78.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('glass-nav-scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withValues(alpha: 0.28)),
            ),
          ),
        ),
        for (var i = 0; i < actions.length; i++)
          Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(
                math.cos(angles[i] * math.pi / 180) * dist,
                math.sin(angles[i] * math.pi / 180) * dist - 110,
              ),
              child: _FanActionButton(
                action: actions[i],
                delay: Duration(milliseconds: i * 45),
                onTap: () {
                  onDismiss();
                  actions[i].onTap();
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Pops in with a spring-eased scale, staggered by [delay] so successive
/// fan buttons appear slightly after one another (mirrors the mockup's
/// per-index stagger). Collapses to an instant appearance when the
/// platform/user has reduced motion enabled.
class _FanActionButton extends StatefulWidget {
  const _FanActionButton({
    required this.action,
    required this.onTap,
    required this.delay,
  });

  final GlassNavQuickAction action;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_FanActionButton> createState() => _FanActionButtonState();
}

class _FanActionButtonState extends State<_FanActionButton> {
  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _appeared = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _appeared = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final shown = _appeared || reduced;

    return AnimatedScale(
      scale: shown ? 1.0 : 0.3,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      child: AnimatedOpacity(
        opacity: shown ? 1.0 : 0.0,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: widget.onTap,
            customBorder: const CircleBorder(),
            child: Semantics(
              label: widget.action.label,
              button: true,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Colors.white24),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black38,
                        blurRadius: 16,
                        offset: Offset(0, 6)),
                  ],
                ),
                child: Icon(widget.action.icon,
                    color: Theme.of(context).colorScheme.onSurface, size: 19),
              ),
            ),
          ),
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
