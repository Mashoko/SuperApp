import 'package:mvvm_sip_demo/users_client.dart';

Future<void> main() async {
  final client = UsersClient(
    packageId: 'org.africom.catchapp',
    secure: false,
  );

  print('🔍 Checking balance...');

  try {
    final resp = await client.getAccountBalance(
      username: '+263783428458',
      // password: 'YOUR_PASSWORD_HERE', // uncomment if backend requires password
    );

    print('Status: ${resp.status}');
    print('Balance: ${resp.balance}');
    print('Alias: ${resp.alias}');
    print('Domain: ${resp.domain}');

    if (resp.hasError()) {
      print('❌ Error: ${resp.error.localizedDescription}');
      print('Debug: ${resp.error.debugDescription}');
    }
  } finally {
    await client.close();
  }
}
