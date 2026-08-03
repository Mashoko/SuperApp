import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../features/call/presentation/views/call_view.dart';
import '../../features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import '../../features/recents/data/models/call_log_status.dart';
import '../../features/recents/data/models/recent_call.dart';
import '../services/balance_refresh_coordinator.dart';
import '../utils/call_log_status_resolution.dart';

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

      // ── Record the moment the call is answered ─────────────────────────────
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        _connectedAt[callId] = DateTime.now();

      // ── Log the call, either direction, exactly once, on end ───────────────
      case CallStateEnum.ENDED:
        _handleCallEnded(call, callState, callId);
        _balanceRefreshCoordinator.refreshAfterCall();

      // ── Log the call, either direction, exactly once, on failure ───────────
      case CallStateEnum.FAILED:
        _connectedAt.remove(callId);
        if (_isSystemFailure(callState.cause)) {
          _logCall(call, status: CallLogStatus.failed, durationSeconds: null);
        } else {
          final isIncoming =
              call.direction.toString().toUpperCase().contains('INCOMING');
          final status = resolveCallLogStatus(
            isIncoming: isIncoming,
            didConnect: false,
            causeCode: callState.cause?.status_code?.toString() ?? '',
          );
          _logCall(call, status: status, durationSeconds: null);
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

    int? durationSeconds;
    final didConnect = connectedTime != null;

    if (didConnect) {
      durationSeconds = DateTime.now().difference(connectedTime).inSeconds;
    }

    final status = resolveCallLogStatus(
      isIncoming: isIncoming,
      didConnect: didConnect,
      causeCode: callState.cause?.status_code?.toString() ?? '',
    );

    _logCall(call, status: status, durationSeconds: durationSeconds);
  }

  Future<void> _logCall(
    Call call, {
    required CallLogStatus status,
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
      status: status,
      direction: isIncoming ? 'incoming' : 'outgoing',
      durationSeconds: durationSeconds,
    ));
  }

  static const _systemFailureCauses = {
    'Connection Error',
    'Internal Error',
    'WebRTC Error',
    'Dialog Error',
    'Bad Media Description',
    'User Denied Media Access',
    'SIP Failure Code',
    'Authentication Error',
    'RTP Timeout',
    'Incompatible SDP',
    'Missing SDP',
  };

  bool _isSystemFailure(dynamic cause) =>
      _systemFailureCauses.contains(cause?.cause);

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
