import '../entities/sip_user.dart';
import '../../../../core/utils/result.dart';

abstract class RegistrationRepository {
  Future<Result<void>> register(SipUser user);
  Future<Result<SipUser?>> getSavedUser();
  Future<Result<void>> saveUser(SipUser user);
  Future<Result<void>> unregister();
}

