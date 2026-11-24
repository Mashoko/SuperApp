import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../help_support/presentation/views/help_support_view.dart';
import '../../login/presentation/sign_out.dart';
import 'kyc_form_view.dart';
import 'kyc_gate_scope.dart';
import 'kyc_status_controller.dart';
import 'mandatory_kyc_view.dart';

/// Covers the whole app with [MandatoryKycView] while verification is
/// launched and the account is restricted, except while a call is active:
/// then the gate steps aside so the call screen can be seen and used, and it
/// returns when the call ends.
///
/// Placed in `MaterialApp.builder`, above the app's navigator. The app stays
/// mounted underneath (its state is kept) but cannot be tapped, focused or
/// read by screen readers. The gate has its own navigator for the form and
/// support pages; those routes are discarded when the gate closes.
class KycGate extends StatefulWidget {
  const KycGate({
    super.key,
    required this.child,
    this.navigatorKey,
    this.callActive,
    this.navigatorObserver,
    this.onSignOut,
    this.supportBuilder,
  });

  final Widget child;

  /// The app's root navigator. Needed so system back is caught while the
  /// gate is shown (back is delivered to the root navigator first) and so
  /// sign out can land on the login screen.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// True while a call (incoming or outgoing) is in progress.
  final ValueListenable<bool>? callActive;

  /// Must also be in the app's `MaterialApp.navigatorObservers`. Lets the
  /// gate put its back blocker back on top whenever the app changes its
  /// navigator while the gate is shown (a replace, push or forced pop).
  final KycGateNavigatorObserver? navigatorObserver;

  /// For tests. Defaults to the app's logout path.
  final Future<void> Function()? onSignOut;

  /// For tests. Defaults to [HelpSupportView].
  final WidgetBuilder? supportBuilder;

  @override
  State<KycGate> createState() => _KycGateState();
}

class _KycGateState extends State<KycGate> {
  final _gateNavigatorKey = GlobalKey<NavigatorState>();
  _BackBlockerRoute? _blocker;
  bool _active = false;

  /// Set by a screen inside the gate (the form, on submit) so the gate stays
  /// up on its result until the user taps Done. See [KycGateScope].
  bool _held = false;

  @override
  void initState() {
    super.initState();
    widget.callActive?.addListener(_onCallChanged);
    widget.navigatorObserver?.addListener(_onRootChanged);
  }

  @override
  void didUpdateWidget(KycGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.callActive, widget.callActive)) {
      oldWidget.callActive?.removeListener(_onCallChanged);
      widget.callActive?.addListener(_onCallChanged);
    }
    if (!identical(oldWidget.navigatorObserver, widget.navigatorObserver)) {
      oldWidget.navigatorObserver?.removeListener(_onRootChanged);
      widget.navigatorObserver?.addListener(_onRootChanged);
    }
  }

  @override
  void dispose() {
    widget.callActive?.removeListener(_onCallChanged);
    widget.navigatorObserver?.removeListener(_onRootChanged);
    _removeBlocker();
    super.dispose();
  }

  /// May be called mid-frame: CallView reports `viewClosed` from its
  /// dispose, while the tree is locked.
  void _onCallChanged() => _rebuildSafely();

  void _hold() => _held = true;

  void _release() {
    if (!_held) return;
    _held = false;
    _rebuildSafely();
  }

  /// setState now when the framework allows it, otherwise right after the
  /// current frame (for example when called from a dispose).
  void _rebuildSafely() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    // Called mid-frame (for example from a dispose): rebuild after it.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// The app pushed, popped, removed or replaced a root route. While the
  /// gate is shown, make sure the blocker is still there and on top.
  void _onRootChanged() {
    if (!mounted || !_active) return;
    final blocker = _blocker;
    if (blocker != null && blocker.isActive && blocker.isCurrent) return;
    _syncBlocker();
  }

  void _syncBlocker() {
    // After the frame: the root navigator must not be changed mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_active) {
        _addBlocker();
      } else {
        _removeBlocker();
      }
    });
  }

  /// Idempotent: keeps exactly one blocker, on top of the root navigator.
  void _addBlocker() {
    final blocker = _blocker;
    if (blocker != null && blocker.isActive && blocker.isCurrent) return;
    final root = widget.navigatorKey?.currentState;
    if (root == null) return;
    if (blocker != null && blocker.isActive) root.removeRoute(blocker);
    final route = _BackBlockerRoute(onBack: _handleBack);
    _blocker = route;
    unawaited(root.push(route));
  }

  void _removeBlocker() {
    final blocker = _blocker;
    _blocker = null;
    if (blocker == null) return;
    try {
      final navigator = blocker.navigator;
      if (navigator != null && navigator.mounted && blocker.isActive) {
        navigator.removeRoute(blocker);
      }
    } catch (_) {
      // Teardown: the root navigator is going away too.
    }
  }

  void _handleBack() {
    unawaited(_gateNavigatorKey.currentState?.maybePop());
  }

  void _openForm() {
    final navigator = _gateNavigatorKey.currentState;
    if (navigator == null) return;
    final controller = context.read<KycStatusController>();
    unawaited(navigator
        .push(MaterialPageRoute<bool>(builder: (_) => const KycFormView()))
        .then((_) => mounted ? controller.refresh() : null));
  }

  void _openSupport() {
    _gateNavigatorKey.currentState?.push(MaterialPageRoute<void>(
        builder: widget.supportBuilder ?? (_) => const HelpSupportView()));
  }

  void _signOut() {
    final onSignOut = widget.onSignOut;
    if (onSignOut != null) {
      unawaited(onSignOut());
    } else {
      unawaited(signOutToLogin(widget.navigatorKey?.currentState));
    }
  }

  Route<void> _initialRoute() => MaterialPageRoute<void>(
        builder: (_) => PopScope(
          canPop: false,
          child: MandatoryKycView(
            onCompleteNow: _openForm,
            onContactSupport: _openSupport,
            onSignOut: _signOut,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KycStatusController>();
    final inCall = widget.callActive?.value ?? false;
    final active =
        !inCall && (_held || (controller.launched && controller.isRestricted));
    final blocker = _blocker;
    final blockerMissing = blocker == null || !blocker.isActive;
    if (active != _active || (active && blockerMissing)) {
      _active = active;
      _syncBlocker();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Always the first child so the app keeps its element and state.
        ExcludeFocus(
          excluding: active,
          child: ExcludeSemantics(
            excluding: active,
            child: IgnorePointer(
              ignoring: active,
              child: TickerMode(enabled: !active, child: widget.child),
            ),
          ),
        ),
        if (active)
          KycGateScope(
            onHold: _hold,
            onRelease: _release,
            child: HeroControllerScope.none(
              child: Navigator(
                key: _gateNavigatorKey,
                onGenerateInitialRoutes: (navigator, initialRoute) =>
                    [_initialRoute()],
                onGenerateRoute: (_) => _initialRoute(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Reports every change to the app's root navigator to the [KycGate].
class KycGateNavigatorObserver extends NavigatorObserver with ChangeNotifier {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      notifyListeners();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      notifyListeners();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      notifyListeners();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      notifyListeners();
}

/// An invisible route pushed on the app's root navigator while the gate is
/// shown. System back goes to the root navigator first; this route refuses
/// to pop and hands back to the gate's own navigator instead, so back never
/// pops the app's pages or closes the app.
class _BackBlockerRoute extends PopupRoute<void> {
  _BackBlockerRoute({required this.onBack});

  final VoidCallback onBack;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onBack();
        },
        child: const SizedBox.shrink(),
      );
}
