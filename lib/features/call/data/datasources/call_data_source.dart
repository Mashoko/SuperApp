import 'package:sip_ua/sip_ua.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class CallDataSource {
  Future<Call> makeCall(String destination, {required bool voiceOnly});
  Future<void> acceptCall(Call call, {required bool hasVideo});
  Future<void> hangupCall(Call call);
  Future<void> muteAudio(Call call, bool mute);
  Future<void> muteVideo(Call call, bool mute);
  Future<void> holdCall(Call call, bool hold);
  Future<void> sendDtmf(Call call, String tone);

  Future<void> transferCall(Call call, String target);
  Future<void> toggleSpeaker(bool enabled);
}

class CallDataSourceImpl implements CallDataSource {
  final SIPUAHelper sipHelper;

  CallDataSourceImpl(this.sipHelper);

  @override
  Future<Call> makeCall(String destination, {required bool voiceOnly}) async {
    // This will be handled by the repository with media stream
    throw UnimplementedError('Use repository method with media stream');
  }

  @override
  Future<void> acceptCall(Call call, {required bool hasVideo}) async {
    // This will be handled by the repository with media stream
    throw UnimplementedError('Use repository method with media stream');
  }

  @override
  Future<void> hangupCall(Call call) async {
    try {
      call.hangup({'status_code': 603});
    } catch (e) {
      // Ignore InvalidStateError if call is already ended
      if (e.toString().contains('InvalidStateError')) {
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> muteAudio(Call call, bool mute) async {
    if (mute) {
      call.mute(true, false);
    } else {
      call.unmute(true, false);
    }
  }

  @override
  Future<void> muteVideo(Call call, bool mute) async {
    if (mute) {
      call.mute(false, true);
    } else {
      call.unmute(false, true);
    }
  }

  @override
  Future<void> holdCall(Call call, bool hold) async {
    if (hold) {
      call.hold();
    } else {
      call.unhold();
    }
  }

  @override
  Future<void> sendDtmf(Call call, String tone) async {
    call.sendDTMF(tone);
  }

  @override
  Future<void> transferCall(Call call, String target) async {
    call.refer(target);
  }

  @override
  Future<void> toggleSpeaker(bool enabled) async {
    // Note: Helper is from flutter_webrtc
    Helper.setSpeakerphoneOn(enabled);
  }
}

