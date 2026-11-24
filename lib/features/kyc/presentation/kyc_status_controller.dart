import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/kyc_models.dart';
import '../data/kyc_service.dart';

const _pollInterval = Duration(minutes: 30);

/// App-wide KYC status. Refreshed after sign-in, on app resume, after submit,
/// and every 30 minutes while the app is in the foreground.
class KycStatusController extends ChangeNotifier with WidgetsBindingObserver {
  KycStatusController(this._service) {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    // The binding drops a repeated identical lifecycle state, so a controller
    // built after launch never sees the initial `resumed`. Start polling now.
    final state = binding.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _startTimer();
  }

  final KycService _service;

  KycStatus? status;
  bool loading = false;
  String? error;

  bool _restrictedFlag = false;
  Future<void>? _inFlight;
  Timer? _timer;
  bool _disposed = false;
  int _generation = 0;

  bool get launched => status?.launched ?? false;
  bool get isRestricted => _restrictedFlag || (status?.isRestricted ?? false);

  /// Single-flight: concurrent callers share one request.
  Future<void> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;
    late final Future<void> run;
    run = _doRefresh().whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
    return _inFlight = run;
  }

  /// Drops any running refresh so its result can never be applied.
  void _invalidate() {
    _generation++;
    _inFlight = null;
  }

  Future<void> _doRefresh() async {
    final gen = _generation;
    if (status == null) {
      loading = true;
      _notify();
    }
    try {
      final fresh = await _service.getStatus();
      if (gen != _generation) return;
      status = fresh;
      error = null;
      if (!fresh.isRestricted) _restrictedFlag = false;
    } on KycApiException catch (e) {
      if (gen != _generation) return;
      if (e.statusCode == 401) {
        loading = false;
        clear();
        return;
      }
      error = e.message;
    } catch (_) {
      if (gen != _generation) return;
      error = 'Something went wrong. Please try again.';
    }
    loading = false;
    _notify();
  }

  /// Idempotent: shows the gate immediately and triggers one shared refresh.
  void markRestricted() {
    if (!_restrictedFlag) {
      // A refresh started earlier must not clear this flag with a stale
      // non-restricted snapshot.
      _invalidate();
      _restrictedFlag = true;
      _notify();
    }
    unawaited(refresh());
  }

  /// Called right after a successful submit: shows PENDING_REVIEW locally so
  /// the gate lifts even if the follow-up refresh fails. A later successful
  /// refresh replaces it as usual. Does nothing without a status.
  void applySubmitted() {
    final current = status;
    if (current == null) return;
    // A refresh started before the submit must not bring back the old status.
    _invalidate();
    status = KycStatus(
      launched: current.launched,
      status: 'PENDING_REVIEW',
      underlyingStatus: 'PENDING_REVIEW',
      deadline: current.deadline,
      exemptUntil: current.exemptUntil,
      progress: current.progress,
      outstanding: current.outstanding,
      draft: current.draft,
      documents: current.documents,
      history: current.history,
      rejectionReason: current.rejectionReason,
      correctionNotes: current.correctionNotes,
      phone: current.phone,
    );
    _restrictedFlag = false;
    loading = false;
    _notify();
  }

  void clear() {
    _invalidate();
    status = null;
    error = null;
    loading = false;
    _restrictedFlag = false;
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(refresh());
        _startTimer();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _timer?.cancel();
        _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
