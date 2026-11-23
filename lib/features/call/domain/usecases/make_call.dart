import '../repositories/call_repository.dart';
import '../../../../core/utils/result.dart';
import '../../../kyc/domain/emergency_numbers.dart';

class MakeCall {
  final CallRepository repository;
  final bool Function()? isKycRestricted;

  MakeCall(this.repository, {this.isKycRestricted});

  Future<Result<void>> call(String destination, {required bool voiceOnly}) async {
    final blocked = kycCallBlockReason(
      destination,
      isRestricted: isKycRestricted ?? () => false,
    );
    if (blocked != null) return Failure(blocked);
    return repository.makeCall(destination, voiceOnly: voiceOnly);
  }
}
