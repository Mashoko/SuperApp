import '../repositories/call_repository.dart';
import '../../../../core/utils/result.dart';

class MakeCall {
  final CallRepository repository;

  MakeCall(this.repository);

  Future<Result<void>> call(String destination, {required bool voiceOnly}) {
    return repository.makeCall(destination, voiceOnly: voiceOnly);
  }
}

