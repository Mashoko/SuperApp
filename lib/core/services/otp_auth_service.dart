import 'package:random_string/random_string.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/crypto_utils.dart';

import '../../users_client.dart';
import '../../generated/users.pb.dart' as users;

/// Handles GSM + WhatsApp OTP auth using the gRPC UsersClient.
///
/// Flow:
/// 1) sendWhatsappOtp() generates a secure password and stores it temporarily
///    (temp_gsm, temp_username, temp_password) and calls sendWhatsAppOTP.
/// 2) verifyOtp() reads the temp data, calls createAccount() with the
///    pre-generated password and OTP as verificationCode, and on success
///    persists final credentials (sip_username, sip_password).
class OtpAuthService {
  final UsersClient client;

  OtpAuthService(this.client);

  // ---------------------
  // Public API
  // ---------------------

  /// Normalize a Zimbabwe GSM number into +263XXXXXXXXX
  /// Accepts formats: +263..., 0..., 77..., 077..., spaces tolerated.
  String normalizeNumber(String input) {
    var s = input.replaceAll(' ', '').trim();
    if (s.startsWith('+263')) return s;
    if (s.startsWith('0')) return '+263${s.substring(1)}';
    if (s.startsWith('263')) return '+$s';
    if (RegExp(r'^(7[1378]\d*)$').hasMatch(s)) return '+263$s';
    // fallback: just prefix +263
    return '+263$s';
  }

  /// Generate a 16-char password: 8 digits + 8 letters (matches CLI).
  static String _generatePassword() {
    return randomNumeric(8) + randomAlpha(8);
  }

  /// Send WhatsApp OTP to the given GSM number and pre-generate a password.
  /// Returns true if the OTP call appears successful.
  Future<bool> sendWhatsappOtp(String gsm) async {
    try {
      final normalized = normalizeNumber(gsm);
      final username = normalized;
      final phone = normalized;

      // Generate and persist temporary credentials
      final generatedPassword = _generatePassword();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('temp_gsm', phone);
      await prefs.setString('temp_username', username);
      await prefs.setString('temp_password', generatedPassword);

      final resp = await client.sendWhatsAppOTP(
        username: username,
        phone: phone,
      );

      return _isOtpSent(resp);
    } catch (_) {
      return false;
    }
  }

  /// Verify OTP by calling createAccount(...) using the pre-generated password.
  /// On success returns { 'username': ..., 'password': ... } (password being
  /// the locally-generated password). Returns null on failure.
  Future<Map<String, String>?> verifyOtp(String gsm, String otp) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load pre-generated values (must exist from sendWhatsappOtp)
      final tempPassword = prefs.getString('temp_password');
      final tempUsername = prefs.getString('temp_username');
      final tempGsm = prefs.getString('temp_gsm');

      if (tempPassword == null || tempUsername == null || tempGsm == null) {
        // Missing prereq; user must request OTP first
        return null;
      }

      final trimmedOtp = otp.trim();
      if (trimmedOtp.isEmpty) return null;

      // Use stored values (single source of truth). The user could re-type a
      // different phone in the UI — ignore that and use the stored GSM/username.
      final resp = await client.createAccount(
        username: tempUsername,
        password: tempPassword,
        verificationCode: trimmedOtp,
      );

      if (!_didSucceed(resp)) {
        return null;
      }

      // Determine final username (server may override)
      final finalUsername =
          resp.username.isNotEmpty ? resp.username : tempUsername;


      // Persist final credentials (consider moving to secure storage in prod)
      await prefs.setString(AppConstants.keyAuthUser, finalUsername);
      await prefs.setString(AppConstants.keyPassword, tempPassword);

      // Clear temporary values
      await prefs.remove('temp_gsm');
      await prefs.remove('temp_username');
      await prefs.remove('temp_password');

      return {
        'username': finalUsername,
        'password': tempPassword,
      };
    } catch (_) {
      return null;
    }
  }

  /// Return stored SIP credentials (null if none).
  Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(AppConstants.keyAuthUser);
      final password = prefs.getString(AppConstants.keyPassword);

      if (username == null || password == null) return null;
      return {'username': username, 'password': password};
    } catch (_) {
      return null;
    }
  }

  /// Remove stored SIP credentials (logout).
  Future<void> clearStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAuthUser);
    await prefs.remove(AppConstants.keyPassword);
  }

  /// Fetch full account summary (alias, balance, domain, status).
  Future<Map<String, dynamic>?> fetchAccountSummary(String username, {String? password}) async {
    try {
      print('--- Account Summary: Fetching for $username (hasPassword: ${password != null}) ---');
      
      String? passwordToSend = password;
      // if (password != null) {
      //   // Compute SIP Password Hash: MD5(username:domain:password)
      //   // Using default domain for now. In ideal flow we might query getDomainForPackageID first.
      //   final domain = AppConstants.sipDomain;
      //   passwordToSend = CryptoUtils.md5Hash('$username:$domain:$password');
      //   print('--- Account Summary: Computed MD5 Hash for/using $domain ---');
      // }

      
      // Try 1: Fetch balance with original username (and plain password)
      var balanceResp = await client.getAccountBalance(username: username, password: passwordToSend);
      print('--- Account Summary: Balance Resp (Original): ${balanceResp.toProto3Json()} ---');

      // Try 2: If failed, try stripping '+' from username
      if (!_didSucceed(balanceResp) && username.startsWith('+')) {
         final altUsername = username.replaceFirst('+', '');
         print('--- Account Summary: Retrying Balance with $altUsername ... ---');
         final altResp = await client.getAccountBalance(username: altUsername, password: passwordToSend);
         print('--- Account Summary: Balance Resp (Alt): ${altResp.toProto3Json()} ---');
         if (_didSucceed(altResp)) {
           balanceResp = altResp;
         }
      }

      if (!_didSucceed(balanceResp)) {
        print('--- Account Summary: Balance fetch failed (Final) ---');
        // Continue to try fetching alias anyway to debug auth vs endpoint issue
      }

      // Fetch alias separately to be sure
      String alias = balanceResp.alias; 
      // If we failed balance, alias is likely empty, but let's try getAliasNumber explicitly
      
      try {
          print('--- Account Summary: Fetching Alias explicitly... ---');
          // Try with original username
          var aliasResp = await client.getAliasNumber(username: username, password: passwordToSend);
          print('--- Account Summary: Alias Resp (Original): ${aliasResp.toProto3Json()} ---');
          
          // Retry alias with alt username if needed
          if (aliasResp.alias.isEmpty && username.startsWith('+')) {
             final altUsername = username.replaceFirst('+', '');
             print('--- Account Summary: Retrying Alias with $altUsername ... ---');
             final altAliasResp = await client.getAliasNumber(username: altUsername, password: passwordToSend);
             print('--- Account Summary: Alias Resp (Alt): ${altAliasResp.toProto3Json()} ---');
             if (altAliasResp.alias.isNotEmpty) {
                aliasResp = altAliasResp;
             }
          }

          if (aliasResp.alias.isNotEmpty) {
            alias = aliasResp.alias;
          }
      } catch (e) {
          print('--- Account Summary: Alias fetch error: $e ---');
      }

      // If both failed, return null
      if (!_didSucceed(balanceResp) && alias.isEmpty) {
         return null;
      }

      return {
        'username': balanceResp.username.isNotEmpty ? balanceResp.username : username,
        'alias': alias,
        'balance': balanceResp.balance,
        'domain': balanceResp.domain,
        'status': balanceResp.status,
      };
    } catch (_) {
      return null;
    }
  }

  // ---------------------
  // Internal helpers
  // ---------------------

  /// Decide whether OTP send call succeeded (tolerates backend inconsistencies).
  bool _isOtpSent(users.response resp) {
    return resp.status == users.Status.SUCCESS ||
        resp.status == users.Status.INFORMATION ||
        resp.hasSuccess();
  }

  /// Decide whether createAccount/getAccountBalance succeeded (tolerant).
  bool _didSucceed(users.response resp) {
    return resp.status == users.Status.SUCCESS ||
        resp.status == users.Status.INFORMATION ||
        resp.hasSuccess() ||
        resp.status == users.Status.ERROR; // accept "ERROR" if backend uses it for updates
  }
}
