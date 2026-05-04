import 'package:flutter/material.dart';

/// Subtle press scale using [AnimationController].
class ScaleTapWrapper extends StatefulWidget {
  const ScaleTapWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.lowerBound = 0.96,
  });

  final Widget child;
  final VoidCallback onTap;
  final double lowerBound;

  @override
  State<ScaleTapWrapper> createState() => _ScaleTapWrapperState();
}

class _ScaleTapWrapperState extends State<ScaleTapWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 120),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: widget.lowerBound,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down() => _controller.forward();
  void _up() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) {
        _up();
        widget.onTap();
      },
      onTapCancel: _up,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
