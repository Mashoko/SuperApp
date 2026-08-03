import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../domain/usecases/make_call.dart';
import '../../domain/usecases/accept_call.dart';
import '../../domain/usecases/hangup_call.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/entities/phone_call_state.dart';
import '../../../../core/utils/result.dart';

class CallViewModel extends ChangeNotifier {
  final MakeCall makeCallUseCase;
  final AcceptCall acceptCallUseCase;
  final HangupCall hangupCallUseCase;
  final CallRepository callRepository;

  CallViewModel(
    this.makeCallUseCase,
    this.acceptCallUseCase,
    this.hangupCallUseCase,
    this.callRepository,
  );

  // ── Low-level SIP state (used by action-button rendering) ──────────────────
  Call? _currentCall;
  CallStateEnum _callState = CallStateEnum.NONE;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isOnHold = false;
  bool _isSpeakerOn = false;
  bool _isVoiceOnly = false;
  String? _remoteIdentity;

  // ── High-level telephony state machine ────────────────────────────────────
  PhoneCallState _phoneState = PhoneCallState.idle;
  bool _wasConnected = false;

  // ── Timer ──────────────────────────────────────────────────────────────────
  Timer? _durationTimer;
  Timer? _timeoutTimer;
  int _elapsedSeconds = 0;

  // ── Public getters ─────────────────────────────────────────────────────────
  Call? get currentCall => _currentCall;
  CallStateEnum get callState => _callState;
  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get isOnHold => _isOnHold;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVoiceOnly => _isVoiceOnly;
  String? get remoteIdentity => _remoteIdentity;
  PhoneCallState get phoneState => _phoneState;
  int get elapsedSeconds => _elapsedSeconds;

  String get callDuration {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Call initiation ────────────────────────────────────────────────────────

  Future<String?> makeCall(String destination, {required bool voiceOnly}) async {
    final result = await makeCallUseCase.call(destination, voiceOnly: voiceOnly);
    if (result is Success) {
      _isVoiceOnly = voiceOnly;
      notifyListeners();
      return null;
    }
    if (result is Failure) return result.message;
    return 'Failed to start call.';
  }

  /// Called when the `CallView` opens. Sets the initial phone state from the
  /// call object so the UI is correct even before any SIP events arrive.
  void setCall(Call call) {
    _currentCall = call;
    _isVoiceOnly = call.voiceOnly;
    _wasConnected = false;
    _elapsedSeconds = 0;

    final isIncoming =
        call.direction.toString().toUpperCase().contains('INCOMING');

    if (call.state == CallStateEnum.CONFIRMED) {
      // Edge case: view opened after the call was already confirmed.
      _wasConnected = true;
      _phoneState = PhoneCallState.connected;
      _startDurationTimer();
    } else {
      _phoneState =
          isIncoming ? PhoneCallState.incoming : PhoneCallState.calling;
      if (!isIncoming) _startTimeoutTimer();
    }

    notifyListeners();
  }

  Future<void> acceptCall(Call call, {required bool hasVideo}) async {
    final result = await acceptCallUseCase.call(call, hasVideo: hasVideo);
    if (result is Success) {
      _currentCall = call;
      _isVoiceOnly = !hasVideo;
      notifyListeners();
    }
  }

  // ── Main SIP → UI state translator ────────────────────────────────────────

  /// Translates a raw SIP event into the high-level [PhoneCallState].
  /// Call this from the View's `callStateChanged` handler.
  void onSipStateChanged(Call call, CallState sipState, String direction) {
    final isIncoming = direction.toUpperCase().contains('INCOMING');

    // Propagate the raw SIP state for use by action buttons.
    if (sipState.state != CallStateEnum.STREAM &&
        sipState.state != CallStateEnum.MUTED &&
        sipState.state != CallStateEnum.UNMUTED) {
      _callState = sipState.state;
    }

    switch (sipState.state) {
      // ── Pre-connect ──────────────────────────────────────────────────────
      case CallStateEnum.CALL_INITIATION:
      case CallStateEnum.CONNECTING:
        if (isIncoming) {
          _updatePhoneState(PhoneCallState.incoming);
        } else {
          _updatePhoneState(PhoneCallState.calling);
          _startTimeoutTimer();
        }

      // ── Remote ringing (SIP 180 Ringing received by caller) ──────────────
      case CallStateEnum.PROGRESS:
        if (!isIncoming) {
          _updatePhoneState(PhoneCallState.ringing);
        }

      // ── Connected ────────────────────────────────────────────────────────
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        _cancelTimeoutTimer();
        if (!_wasConnected) {
          _wasConnected = true;
          _elapsedSeconds = 0;
          _startDurationTimer();
        }
        _updatePhoneState(PhoneCallState.connected);

      // ── Hold / unhold ────────────────────────────────────────────────────
      case CallStateEnum.HOLD:
        _isOnHold = true;
        notifyListeners();

      case CallStateEnum.UNHOLD:
        _isOnHold = false;
        notifyListeners();

      // ── Mute ─────────────────────────────────────────────────────────────
      case CallStateEnum.MUTED:
        if (sipState.audio == true) _isAudioMuted = true;
        if (sipState.video == true && !_isVoiceOnly) _isVideoMuted = true;
        notifyListeners();

      case CallStateEnum.UNMUTED:
        if (sipState.audio == true) _isAudioMuted = false;
        if (sipState.video == true && !_isVoiceOnly) _isVideoMuted = false;
        notifyListeners();

      // ── Ended ────────────────────────────────────────────────────────────
      case CallStateEnum.ENDED:
        _handleSipEnded(isIncoming: isIncoming, sipState: sipState);

      case CallStateEnum.FAILED:
        _cancelTimeoutTimer();
        _stopDurationTimer();
        _updatePhoneState(
            _wasConnected ? PhoneCallState.ended : PhoneCallState.failed);

      default:
        break;
    }
  }

  void _handleSipEnded({required bool isIncoming, required CallState sipState}) {
    _cancelTimeoutTimer();
    _stopDurationTimer();

    if (isIncoming && !_wasConnected) {
      // 487 = caller cancelled (Request Terminated), 408 = timeout.
      final cause = sipState.cause?.cause ?? '';
      final callerCancelled = cause == '487' || cause == '408';
      _updatePhoneState(
          callerCancelled ? PhoneCallState.missed : PhoneCallState.declined);
    } else {
      _updatePhoneState(PhoneCallState.ended);
    }
  }

  // ── User-initiated hang-up ─────────────────────────────────────────────────

  Future<void> hangup() async {
    if (_currentCall != null) {
      if (_callState != CallStateEnum.ENDED &&
          _callState != CallStateEnum.FAILED) {
        try {
          await hangupCallUseCase.call(_currentCall!);
        } catch (e) {
          debugPrint('Error hanging up call: $e');
        }
      }
    }
    _cancelTimeoutTimer();
    _stopDurationTimer();

    if (!_phoneState.isTerminal) {
      final wasIncoming = _currentCall?.direction
              .toString()
              .toUpperCase()
              .contains('INCOMING') ??
          false;
      _updatePhoneState(wasIncoming && !_wasConnected
          ? PhoneCallState.declined
          : PhoneCallState.ended);
    }

    _currentCall = null;
    _callState = CallStateEnum.ENDED;
    notifyListeners();
  }

  // ── In-call controls ───────────────────────────────────────────────────────

  Future<void> toggleMuteAudio() async {
    if (_currentCall != null) {
      _isAudioMuted = !_isAudioMuted;
      await callRepository.muteAudio(_currentCall!, _isAudioMuted);
      notifyListeners();
    }
  }

  void setAudioMuted(bool isMuted) {
    _isAudioMuted = isMuted;
    notifyListeners();
  }

  Future<void> toggleMuteVideo() async {
    if (_currentCall != null) {
      _isVideoMuted = !_isVideoMuted;
      await callRepository.muteVideo(_currentCall!, _isVideoMuted);
      notifyListeners();
    }
  }

  void setVideoMuted(bool isMuted) {
    _isVideoMuted = isMuted;
    notifyListeners();
  }

  Future<void> toggleHold() async {
    if (_currentCall != null) {
      _isOnHold = !_isOnHold;
      await callRepository.holdCall(_currentCall!, _isOnHold);
      notifyListeners();
    }
  }

  void setOnHold(bool isOnHold) {
    _isOnHold = isOnHold;
    notifyListeners();
  }

  Future<void> sendDtmf(String tone) async {
    if (_currentCall != null) {
      await callRepository.sendDtmf(_currentCall!, tone);
    }
  }

  Future<void> transfer(String target) async {
    if (_currentCall != null) {
      await callRepository.transferCall(_currentCall!, target);
    }
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await callRepository.toggleSpeaker(_isSpeakerOn);
    notifyListeners();
  }

  void setRemoteIdentity(String identity) {
    _remoteIdentity = identity;
    notifyListeners();
  }

  /// Updates voice/video mode outside the normal call-setup paths — e.g.
  /// when a mid-call re-invite upgrades a voice call to video. No-ops if
  /// the value doesn't change.
  void setVoiceOnly(bool voiceOnly) {
    if (_isVoiceOnly == voiceOnly) return;
    _isVoiceOnly = voiceOnly;
    notifyListeners();
  }

  // ── Timer management ───────────────────────────────────────────────────────

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_phoneState == PhoneCallState.calling ||
          _phoneState == PhoneCallState.ringing) {
        hangup();
      }
    });
  }

  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  // ── State helpers ──────────────────────────────────────────────────────────

  void _updatePhoneState(PhoneCallState state) {
    if (_phoneState == state) return;
    _phoneState = state;
    notifyListeners();
  }

  /// Called by [CallView.dispose] to cancel all timers and reset state
  /// (important because the Provider uses `.value` and won't call [dispose]).
  void resetForDispose() {
    _cancelTimeoutTimer();
    _stopDurationTimer();
    _currentCall = null;
  }

  @override
  void dispose() {
    _cancelTimeoutTimer();
    _stopDurationTimer();
    super.dispose();
  }
}
