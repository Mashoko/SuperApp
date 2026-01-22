import 'package:sip_ua/sip_ua.dart';
import '../../../../core/utils/result.dart';

abstract class CallRepository {
  Future<Result<void>> makeCall(String destination, {required bool voiceOnly});
  Future<Result<void>> acceptCall(Call call, {required bool hasVideo});
  Future<Result<void>> hangupCall(Call call);
  Future<Result<void>> muteAudio(Call call, bool mute);
  Future<Result<void>> muteVideo(Call call, bool mute);
  Future<Result<void>> holdCall(Call call, bool hold);
  Future<Result<void>> sendDtmf(Call call, String tone);

  Future<Result<void>> transferCall(Call call, String target);
  Future<Result<void>> toggleSpeaker(bool enabled);
}

