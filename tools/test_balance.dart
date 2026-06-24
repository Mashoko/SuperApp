// ignore_for_file: avoid_print

import 'package:grpc/grpc.dart';
import 'package:mvvm_sip_demo/generated/payments.pbgrpc.dart' as pay;
import 'package:mvvm_sip_demo/generated/users.pbgrpc.dart' as usr;

const String host      = 'wss.durihub.co.zw';
const int    port      = 50000;
const String domain    = 'localvoip.ai.co.zw';
const String packageId = 'org.duri.maswerasei';

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run tools/test_balance.dart <username> <password>');
    return;
  }

  final username = args[0];
  final password = args[1];

  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print(' Momari gRPC Balance Test');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print(' Host     : $host:$port');
  print(' Username : $username');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  final channel = ClientChannel(
    host,
    port: port,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );

  // ── Test 1: users.proto AccountBalance ────────────────────────────────────
  print('── [users.proto] AccountBalance ──────');
  final userStub = usr.userServiceClient(channel);
  final userReq = usr.request()
    ..username  = username
    ..password  = password
    ..domain    = domain
    ..packageId = packageId;

  try {
    final r = await userStub.accountBalance(userReq)
        .timeout(const Duration(seconds: 10));
    print('  status   : ${r.status.name}  (${r.status.value})');
    print('  balance  : ${r.balance}');
    print('  alias    : ${r.alias.isEmpty ? "(empty)" : r.alias}');
    print('  username : ${r.username.isEmpty ? "(empty)" : r.username}');
    if (r.hasError())   print('  error    : ${r.error.localizedDescription}');
    if (r.hasInfo())    print('  info     : ${r.info.information}');
    if (r.hasSuccess()) print('  success  : ${r.success.localizedDescription}');

    // Interpret balance as nanoseconds → voice minutes
    if (r.balance > 0) {
      final ns = r.balance;
      final d = Duration(microseconds: (ns / 1000).round());
      print('  ↳ as voice minutes : ${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s');
    }
  } on GrpcError catch (e) {
    print('  ✗ gRPC ${e.codeName} (${e.code}): ${e.message}');
  } catch (e) {
    print('  ✗ $e');
  }

  // ── Test 2: payments.proto DealerAccountBalances ───────────────────────────
  print('\n── [payments.proto] DealerAccountBalances ──');
  final payStub = pay.paymentsServiceClient(channel);
  final payReq = pay.requests()
    ..username  = username
    ..password  = password
    ..domain    = domain
    ..packageId = packageId;

  try {
    final r = await payStub.dealerAccountBalances(payReq)
        .timeout(const Duration(seconds: 10));
    print('  status       : ${r.status.name}  (${r.status.value})');
    print('  balance      : ${r.balance}');
    print('  balanceAfter : ${r.balanceAfter}');
    if (r.hasError())   print('  error        : ${r.error.localizedDescription}');
    if (r.hasInfo())    print('  info         : ${r.info.information}');
    if (r.hasSuccess()) print('  success      : ${r.success.localizedDescription}');
  } on GrpcError catch (e) {
    print('  ✗ gRPC ${e.codeName} (${e.code}): ${e.message}');
  } catch (e) {
    print('  ✗ $e');
  }

  await channel.shutdown();
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print(' Done.');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}
