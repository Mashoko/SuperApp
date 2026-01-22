import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/constants.dart';
import '../../domain/entities/sip_user.dart';
import '../models/sip_user_model.dart';
import 'package:sip_ua/sip_ua.dart';

abstract class RegistrationLocalDataSource {
  Future<SipUser?> getSavedUser();
  Future<void> saveUser(SipUser user);
}

class RegistrationLocalDataSourceImpl implements RegistrationLocalDataSource {
  final SharedPreferences sharedPreferences;

  RegistrationLocalDataSourceImpl(this.sharedPreferences);

  @override
  Future<SipUser?> getSavedUser() async {
    try {
      final password = sharedPreferences.getString(AppConstants.keyPassword);
      final authUser = sharedPreferences.getString(AppConstants.keyAuthUser);

      if (authUser == null || authUser.isEmpty) {
        return null;
      }

      // Reconstruct SIP URI from saved username
      final sipUri = '$authUser@${AppConstants.sipDomain}';

      return SipUserModel(
        wsUrl: AppConstants.websocketUrl,
        sipUri: sipUri,
        displayName: authUser, // Display name same as username
        password: password ?? '',
        authUser: authUser,
        port: AppConstants.port,
        selectedTransport: TransportType.WS, // Always use WebSocket
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveUser(SipUser user) async {
    // Save only username and password, other values come from constants
    await sharedPreferences.setString(AppConstants.keyPassword, user.password);
    await sharedPreferences.setString(AppConstants.keyAuthUser, user.authUser);
    // Also save SIP URI for backward compatibility
    await sharedPreferences.setString(AppConstants.keySipUri, user.sipUri ?? '');
    await sharedPreferences.setString(AppConstants.keyDisplayName, user.displayName);
  }
}

