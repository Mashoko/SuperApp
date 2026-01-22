import 'package:mvvm_sip_demo/users_client.dart';

Future<void> main() async {
  final client = UsersClient(
    packageId: 'org.africom.catchapp',
    secure: false,
  );

  print('📨 Sending verification code (SMS) ...');

  try {
    final resp = await client.sendVerificationCode(
      username: '263783428458',
      phone: '+263783428458',
    );

    print('Status: ${resp.status}');
    if (resp.hasInfo()) {
      print('Info: ${resp.info.information}');
    }
    if (resp.hasError()) {
      print('❌ Error: ${resp.error.localizedDescription}');
      print('Debug: ${resp.error.debugDescription}');
    }
  } finally {
    await client.close();
  }
}
