import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/kyc_models.dart';
import '../data/kyc_service.dart';

const _pollInterval = Duration(minutes: 30);

/// App-wide KYC status. Refreshed after sign-in, on app resume, after submit,
/// and every 30 minutes while the app is in the foreground.
class KycStatusController extends ChangeNotifier with WidgetsBindingObserver {
  KycStatusController(this._service) {
    WidgetsBinding.instance.addObserver(this);
  }

  final KycService _service;

  KycStatus? status;
  bool loading = false;
  String? error;

  bool _restrictedFlag = false;
  Future<void>? _inFlight;
  Timer? _timer;
  bool _disposed = false;

  bool get launched => status?.launched ?? false;
  bool get isRestricted => _restrictedFlag || (status?.isRestricted ?? false);

  /// Single-flight: concurrent callers share one request.
  Future<void> refresh() => _inFlight ??= _doRefresh().whenComplete(() {
        _inFlight = null;
      });

  Future<void> _doRefresh() async {
    loading = true;
    _notify();
    try {
      final fresh = await _service.getStatus();
      status = fresh;
      error = null;
      if (!fresh.isRestricted) _restrictedFlag = false;
    } on KycApiException catch (e) {
      if (e.statusCode == 401) {
        loading = false;
        clear();
        return;
      }
      error = e.message;
    } catch (_) {
      error = 'Something went wrong. Please try again.';
    }
    loading = false;
    _notify();
  }

  /// Idempotent: shows the gate immediately and triggers one shared refresh.
  void markRestricted() {
    if (!_restrictedFlag) {
      _restrictedFlag = true;
      _notify();
    }
    unawaited(refresh());
  }

  void clear() {
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
        _timer?.cancel();
        _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _timer?.cancel();
        _timer = null;
    }
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
