// bin/simple.dart
//
// Simple executable to test the UsersClient.

import 'dart:async';
import 'package:mvvm_sip_demo/users_client.dart';

Future<void> main() async {
  print('🔌 Testing UsersClient RPC calls...');

  final client = UsersClient(
    packageId: 'org.africom.catchapp',
    secure: false,
  );

  try {
    // 1. Domain lookup
    final domainResp = await client.getDomainForPackageID();
    print('Domain status: ${domainResp.status}');
    print('Domain: ${domainResp.domain}');
    if (domainResp.hasError()) {
      print('❌ Error: ${domainResp.error.localizedDescription}');
      print('Debug: ${domainResp.error.debugDescription}');
    }

    // 2. Websocket URL from API
    final wsResp = await client.getWebsocketUrlFromApi();
    print('Websocket status: ${wsResp.status}');
    print('Websocket domain: ${wsResp.domain}');
    print('Alias: ${wsResp.alias}');
    if (wsResp.hasError()) {
      print('❌ Error: ${wsResp.error.localizedDescription}');
      print('Debug: ${wsResp.error.debugDescription}');
    }
  } finally {
    await client.close();
  }
}
