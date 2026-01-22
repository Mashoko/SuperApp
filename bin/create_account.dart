import 'package:mvvm_sip_demo/users_client.dart';

Future<void> main() async {
  final client = UsersClient(
    packageId: 'org.africom.catchapp',
    secure: false,
  );

  print('🆕 Creating account...');

  try {
    final resp = await client.createAccount(
      username: 'testuser',
      password: 'YOUR_PASSWORD_HERE',
      verificationCode: '123456',
    );

    print('Status: ${resp.status}');
    if (resp.hasSuccess()) {
      print('✅ Success: ${resp.success.localizedDescription}');
      print('Debug: ${resp.success.debugDescription}');
    }
    if (resp.hasError()) {
      print('❌ Error: ${resp.error.localizedDescription}');
      print('Debug: ${resp.error.debugDescription}');
    }
  } finally {
    await client.close();
  }
}
