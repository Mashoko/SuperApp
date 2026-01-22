
import 'dart:io';
import 'package:mvvm_sip_demo/users_client.dart';
Future<void> main(List<String> args) async {
  final client = UsersClient(
    packageId: 'org.africom.catchapp',
    secure: false,
  );
  String username;
  if (args.isEmpty) {
    stdout.write('Enter username: ');
    username = stdin.readLineSync()?.trim() ?? '';
    if (username.isEmpty) {
      print('Username cannot be empty.');
      return;
    }
  } else {
    username = args[0];
  }
  // Automatically add + if it's missing and looks like a phone number
  if (!username.startsWith('+') && RegExp(r'^[0-9]+$').hasMatch(username)) {
    username = '+$username';
    print('ℹ️  Added missing "+" prefix');
  }
  print('🔍 Retrieving alias number for $username...');
  try {
    final resp = await client.getAliasNumber(username: username);
    print('Status: ${resp.status}');
    print('Alias: ${resp.alias}');
    if (resp.hasError()) {
      print('❌ Error: ${resp.error.localizedDescription}');
      print('Debug: ${resp.error.debugDescription}');
    }
  } finally {
    await client.close();
  }
}
