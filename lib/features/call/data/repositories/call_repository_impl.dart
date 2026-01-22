import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../domain/repositories/call_repository.dart';
import '../../../../core/utils/result.dart';
import '../datasources/call_data_source.dart';

class CallRepositoryImpl implements CallRepository {
  final CallDataSource dataSource;
  final SIPUAHelper sipHelper;

  CallRepositoryImpl(this.dataSource, this.sipHelper);

  @override
  Future<Result<void>> makeCall(String destination,
      {required bool voiceOnly}) async {
    try {
      var mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': voiceOnly
            ? false
            : {
                'mandatory': <String, dynamic>{
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
              }
      };

      MediaStream mediaStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      sipHelper.call(destination,
          voiceOnly: voiceOnly, mediaStream: mediaStream);
      // Note: sipHelper.call returns void, the call object is managed by SIPUAHelper
      // The call object will be available through the SipUaHelperListener
      return const Success(null);
    } catch (e) {
      return Failure('Failed to make call: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> acceptCall(Call call, {required bool hasVideo}) async {
    try {
      var mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': hasVideo
            ? {
                'mandatory': <String, dynamic>{
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
              }
            : false
      };

      MediaStream mediaStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      call.answer(sipHelper.buildCallOptions(!hasVideo),
          mediaStream: mediaStream);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to accept call: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> hangupCall(Call call) async {
    try {
      await dataSource.hangupCall(call);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to hangup call: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> muteAudio(Call call, bool mute) async {
    try {
      await dataSource.muteAudio(call, mute);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to mute audio: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> muteVideo(Call call, bool mute) async {
    try {
      await dataSource.muteVideo(call, mute);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to mute video: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> holdCall(Call call, bool hold) async {
    try {
      await dataSource.holdCall(call, hold);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to hold call: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> sendDtmf(Call call, String tone) async {
    try {
      await dataSource.sendDtmf(call, tone);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send DTMF: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> transferCall(Call call, String target) async {
    try {
      await dataSource.transferCall(call, target);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to transfer call: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> toggleSpeaker(bool enabled) async {
    try {
      await dataSource.toggleSpeaker(enabled);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to toggle speaker: ${e.toString()}');
    }
  }
}

