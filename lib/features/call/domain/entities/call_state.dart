import 'package:sip_ua/sip_ua.dart';

class CallStateEntity {
  final CallStateEnum state;
  final String? remoteIdentity;
  final bool isVoiceOnly;
  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isOnHold;
  final bool isSpeakerOn;

  CallStateEntity({
    required this.state,
    this.remoteIdentity,
    this.isVoiceOnly = false,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.isOnHold = false,
    this.isSpeakerOn = false,
  });
}

