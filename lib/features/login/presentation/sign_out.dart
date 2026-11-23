import 'package:flutter/material.dart';

import '../../../core/di/inject.dart';
import '../../../core/services/otp_auth_service.dart';
import 'views/login_view.dart';

/// The app's logout path: clears the stored credentials, the backend session
/// and the KYC status, then replaces every route on [navigator] with the
/// login screen.
///
/// Takes the navigator rather than a context because the caller's screen may
/// be gone once the credentials are cleared (the KYC gate closes when its
/// status is cleared).
Future<void> signOutToLogin(NavigatorState? navigator) async {
  await getIt<OtpAuthService>().clearStoredCredentials();
  if (navigator == null || !navigator.mounted) return;
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginView()),
    (_) => false,
  );
}
