import 'package:mvvm_sip_demo/users_client.dart';

// Usage:
//   dart run bin/create_account.dart          → sends WhatsApp OTP
//   dart run bin/create_account.dart <otp>    → creates account with that OTP
Future<void> main(List<String> args) async {
  const phone    = '+263735418014';
  const username = '+263735418014';
  const password = 'test12345678';

  final client = UsersClient(
    packageId: 'org.duri.maswerasei',
    secure: false,
  );

  try {
    if (args.isEmpty) {
      // Step 1: Send WhatsApp OTP
      print('\n--- Sending WhatsApp OTP to $phone ---');
      final resp = await client.sendWhatsAppOTP(username: username, phone: phone);

      if (resp.hasSuccess()) {
        print('✅ OTP sent! Check your WhatsApp then run:');
        print('   dart run bin/create_account.dart <otp>');
      } else if (resp.hasError()) {
        print('❌ ${resp.error.localizedDescription}');
      } else {
        print('Status: ${resp.status}');
      }
    } else {
      // Step 2: Create account with provided OTP
      final otp = args[0].trim();
      print('\n--- Creating account with OTP: $otp ---');
      final resp = await client.createAccount(
        username: username,
        password: password,
        verificationCode: otp,
      );

      if (resp.hasSuccess()) {
        print('\n✅ Account created!');
        print('Username : ${resp.username.isNotEmpty ? resp.username : username}');
        print('Domain   : ${resp.domain}');
        print('Alias    : ${resp.alias}');
      } else if (resp.hasError()) {
        print('\n❌ Failed: ${resp.error.localizedDescription}');
        print('Debug    : ${resp.error.debugDescription}');
      } else {
        print('\nStatus: ${resp.status}');
      }
    }
  } finally {
    await client.close();
  }
}
