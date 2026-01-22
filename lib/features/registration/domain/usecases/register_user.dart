import '../entities/sip_user.dart';
import '../repositories/registration_repository.dart';
import '../../../../core/utils/result.dart';

class RegisterUser {
  final RegistrationRepository repository;

  RegisterUser(this.repository);

  Future<Result<void>> call(SipUser user) async {
    return await repository.register(user);
  }
}

