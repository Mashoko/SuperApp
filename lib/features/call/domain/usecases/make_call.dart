import '../repositories/call_repository.dart';
import '../../../../core/utils/result.dart';
import '../../../kyc/domain/emergency_numbers.dart';

class MakeCall {
  final CallRepository repository;
  final bool Function()? isKycRestricted;

  MakeCall(this.repository, {this.isKycRestricted});

  Future<Result<void>> call(String destination, {required bool voiceOnly}) async {
    if (isKycRestricted?.call() == true && !isEmergencyNumber(destination)) {
      return const Failure(
        'Calls are paused until you complete your KYC verification. Emergency calls still work.',
      );
    }
    return repository.makeCall(destination, voiceOnly: voiceOnly);
  }
}
