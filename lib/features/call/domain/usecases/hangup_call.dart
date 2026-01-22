import 'package:sip_ua/sip_ua.dart';
import '../repositories/call_repository.dart';
import '../../../../core/utils/result.dart';

class HangupCall {
  final CallRepository repository;

  HangupCall(this.repository);

  Future<Result<void>> call(Call call) {
    return repository.hangupCall(call);
  }
}

