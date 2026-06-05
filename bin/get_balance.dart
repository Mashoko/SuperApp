import 'package:mvvm_sip_demo/users_client.dart';

Future<void> main() async {
  final client = UsersClient(packageId: 'org.duri.maswerasei', secure: false);
  try {
    final resp = await client.getAccountBalance(
      username: '+263775712940',
      password: 'test12345678',
    );
    if (resp.hasError()) {
      print('Error: ${resp.error.localizedDescription}');
    } else {
      print('Status  : ${resp.status}');
      print('Balance : ${resp.hasBalance() ? resp.balance : "not returned"}');
      print('Username: ${resp.username}');
      print('Alias   : ${resp.alias}');
      print('Domain  : ${resp.domain}');
    }
  } finally {
    await client.close();
  }
}
