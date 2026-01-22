import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../domain/usecases/make_call.dart';
import '../../domain/usecases/accept_call.dart';
import '../../domain/usecases/hangup_call.dart';
import '../../domain/repositories/call_repository.dart';
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

  Call? _currentCall;
  CallStateEnum _callState = CallStateEnum.NONE;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isOnHold = false;
  bool _isSpeakerOn = false;
  bool _isVoiceOnly = false;
  String? _remoteIdentity;
  String _callDuration = '00:00';

  Call? get currentCall => _currentCall;
  CallStateEnum get callState => _callState;
  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get isOnHold => _isOnHold;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVoiceOnly => _isVoiceOnly;
  String? get remoteIdentity => _remoteIdentity;
  String get callDuration => _callDuration;

  Future<void> makeCall(String destination, {required bool voiceOnly}) async {
    final result = await makeCallUseCase.call(destination, voiceOnly: voiceOnly);
    if (result is Success) {
      _isVoiceOnly = voiceOnly;
      // Call object will be set via listener
      notifyListeners();
    }
  }

  void setCall(Call call) {
    _currentCall = call;
    // Ensure the ViewModel knows if it's a voice-only call from the start
    _isVoiceOnly = call.voiceOnly;
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

  Future<void> hangup() async {
    if (_currentCall != null) {
      if (_callState != CallStateEnum.ENDED && _callState != CallStateEnum.FAILED) {
         try {
           await hangupCallUseCase.call(_currentCall!);
         } catch (e) {
           debugPrint('Error hanging up call: $e');
         }
      }
      _currentCall = null;
      _callState = CallStateEnum.ENDED;
      notifyListeners();
    }
  }

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

  void updateCallState(CallStateEnum state) {
    _callState = state;
    notifyListeners();
  }

  void updateCallDuration(String duration) {
    _callDuration = duration;
    notifyListeners();
  }

  void setRemoteIdentity(String identity) {
    _remoteIdentity = identity;
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await callRepository.toggleSpeaker(_isSpeakerOn);
    notifyListeners();
  }
}

