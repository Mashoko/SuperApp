import '../../domain/entities/sip_user.dart';
import '../../domain/repositories/registration_repository.dart';
import '../../../../core/utils/result.dart';
import '../datasources/registration_local_data_source.dart';
import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';

class RegistrationRepositoryImpl implements RegistrationRepository {
  final RegistrationLocalDataSource localDataSource;
  final SIPUAHelper sipHelper;

  RegistrationRepositoryImpl(this.localDataSource, this.sipHelper);

  @override
  Future<Result<void>> register(SipUser user) async {
    // Validate required fields before attempting registration
    if (user.authUser.isEmpty || user.authUser.trim().isEmpty) {
      return const Failure('Username is required');
    }
    
    if (user.password.isEmpty || user.password.trim().isEmpty) {
      return const Failure('Password is required');
    }
    
    if (user.sipUri == null || user.sipUri!.isEmpty) {
      return const Failure('SIP URI is required');
    }

    try {
      // Only unregister when actually registered (unregister() asserts registered).
      try {
        if (sipHelper.registered) {
          await sipHelper.unregister();
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        debugPrint('Error during unregister: $e');
      }

      final host = user.sipUri?.split('@')[1];
      if (host == null || host.isEmpty) {
        return const Failure('Invalid SIP URI format');
      }

      UaSettings settings = UaSettings();
      settings.port = user.port;
      settings.webSocketSettings.extraHeaders = user.wsExtraHeaders ?? {};
      settings.webSocketSettings.allowBadCertificate = true;
      settings.webSocketSettings.userAgent = 'Dart SIP Client v1.0.0';
      settings.tcpSocketSettings.allowBadCertificate = true;
      settings.transportType = TransportType.WS;
      settings.uri = user.sipUri;
      settings.webSocketUrl = user.wsUrl;
      settings.host = host;
      settings.authorizationUser = user.authUser;
      settings.password = user.password; // Use plain password, not ha1
      settings.displayName = user.displayName;
      settings.userAgent = 'Dart SIP Client v1.0.0';
      settings.dtmfMode = DtmfMode.RFC2833;
      settings.contact_uri = 'sip:${user.sipUri}';

      sipHelper.start(settings);
      await saveUser(user);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to register: ${e.toString()}');
    }
  }

  @override
  Future<Result<SipUser?>> getSavedUser() async {
    try {
      final user = await localDataSource.getSavedUser();
      return Success(user);
    } catch (e) {
      return Failure('Failed to get saved user: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> saveUser(SipUser user) async {
    try {
      await localDataSource.saveUser(user);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save user: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> unregister() async {
    try {
      sipHelper.unregister();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to unregister: ${e.toString()}');
    }
  }
}

