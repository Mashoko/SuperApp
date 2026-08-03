import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../features/call/presentation/views/call_view.dart';
import '../../features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import '../../features/recents/data/models/recent_call.dart';
import '../services/balance_refresh_coordinator.dart';

class SipCallManager implements SipUaHelperListener {
  final SIPUAHelper _sipHelper;
  final GlobalKey<NavigatorState> navigatorKey;
  final DialpadViewModel _dialpadViewModel;
  final BalanceRefreshCoordinator _balanceRefreshCoordinator;

  /// Tracks when each call was answered so we can compute accurate duration.
  final Map<String, DateTime> _connectedAt = {};

  SipCallManager(
    this._sipHelper,
    this.navigatorKey,
    this._dialpadViewModel,
    this._balanceRefreshCoordinator,
  ) {
    _sipHelper.addSipUaHelperListener(this);
  }

  void dispose() {
    _sipHelper.removeSipUaHelperListener(this);
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    final callId = call.id ?? call.remote_identity ?? '';

    switch (callState.state) {
      // ── Navigate to CallView on call initiation ────────────────────────────
      case CallStateEnum.CALL_INITIATION:
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => CallView(call: call)),
        );
        // Pre-log outgoing calls immediately so they show in recents.
        if (!call.direction.toString().toUpperCase().contains('INCOMING')) {
          _logCall(call, status: 'initiated', durationSeconds: null);
        }

      // ── Record the moment the call is answered ─────────────────────────────
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        _connectedAt[callId] = DateTime.now();

      // ── Log completed call on end ──────────────────────────────────────────
      case CallStateEnum.ENDED:
        _handleCallEnded(call, callState, callId);
        _balanceRefreshCoordinator.refreshAfterCall();

      case CallStateEnum.FAILED:
        _connectedAt.remove(callId);
        if (call.direction.toString().toUpperCase().contains('INCOMING')) {
          _logCall(call, status: 'failed', durationSeconds: null);
        }
        _balanceRefreshCoordinator.refreshAfterCall();

      default:
        break;
    }
  }

  void _handleCallEnded(Call call, CallState callState, String callId) {
    final connectedTime = _connectedAt.remove(callId);
    final isIncoming =
        call.direction.toString().toUpperCase().contains('INCOMING');

    if (!isIncoming) return; // Outgoing already logged at initiation.

    int? durationSeconds;
    String status;

    if (connectedTime != null) {
      durationSeconds =
          DateTime.now().difference(connectedTime).inSeconds;
      status = 'completed';
    } else {
      // Never connected — missed or declined.
      final cause = callState.cause?.cause ?? '';
      final callerCancelled = cause == '487' || cause == '408';
      status = callerCancelled ? 'missed' : 'declined';
    }

    _logCall(call, status: status, durationSeconds: durationSeconds);
  }

  Future<void> _logCall(
    Call call, {
    required String status,
    required int? durationSeconds,
  }) async {
    String number = call.remote_identity ?? 'Unknown';

    // Extract clean number from SIP URI  (e.g. "Name <sip:1001@domain>").
    final match = RegExp(r'sip:([^@>]+)').firstMatch(number);
    if (match != null) number = match.group(1)!;

    final isIncoming =
        call.direction.toString().toUpperCase().contains('INCOMING');

    await _dialpadViewModel.addRecentCall(RecentCall(
      number: number,
      timestamp: DateTime.now(),
      isMissed: status == 'missed',
      direction: isIncoming ? 'incoming' : 'outgoing',
      durationSeconds: durationSeconds,
    ));
  }

  // ── Unused overrides ───────────────────────────────────────────────────────

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void registrationStateChanged(RegistrationState state) {}
  @override
  void transportStateChanged(TransportState state) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
