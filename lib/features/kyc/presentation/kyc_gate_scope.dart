import 'package:flutter/widgets.dart';

/// Lets a screen inside the KYC gate keep the gate up for a moment after the
/// account stops being restricted, so the user sees the result of what they
/// did (for example the form's thanks state) before the app comes back.
///
/// Screens outside the gate find no scope and nothing happens.
class KycGateScope extends InheritedWidget {
  const KycGateScope({
    super.key,
    required this.onHold,
    required this.onRelease,
    required super.child,
  });

  final VoidCallback onHold;
  final VoidCallback onRelease;

  static KycGateScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<KycGateScope>();

  /// Keeps the gate shown until [release], even if the restriction lifts.
  void holdUntilDone() => onHold();

  /// Lets the gate close if the account is no longer restricted. Safe to
  /// call more than once and from `dispose`.
  void release() => onRelease();

  @override
  bool updateShouldNotify(KycGateScope oldWidget) => false;
}
