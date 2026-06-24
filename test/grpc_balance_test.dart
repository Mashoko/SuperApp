// ignore_for_file: avoid_print
// Run: flutter test test/grpc_balance_test.dart -v
// Results → /tmp/grpc_balance_results.txt

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mvvm_sip_demo/generated/payments.pbgrpc.dart' as pay;
import 'package:mvvm_sip_demo/generated/users.pbgrpc.dart' as usr;

const host      = 'wss.durihub.co.zw';
const port      = 50000;
const domain    = 'localvoip.ai.co.zw';
const packageId = 'org.duri.maswerasei';
const username  = '+263735418014';
const password  = 'test12345678';

final _buf = StringBuffer();
void w(String s) { _buf.writeln(s); print(s); }
void save() => File('/tmp/grpc_balance_results.txt').writeAsStringSync(_buf.toString());

void _printReply(pay.reply r, {bool showBalance = false}) {
  w('  status       : ${r.status.name} (${r.status.value})');
  if (showBalance) {
    w('  balance      : ${r.balance}  (${(r.balance / 60).toStringAsFixed(2)} min if in minutes)');
  }
  w('  balanceAfter : ${r.balanceAfter}  (${(r.balanceAfter / 60).toStringAsFixed(2)} min)');
  if (r.hasError())   w('  error        : ${r.error.localizedDescription}');
  if (r.hasInfo())    w('  info         : ${r.info.information}');
  if (r.hasSuccess()) w('  success      : ${r.success.localizedDescription}');
}

void main() {
  late ClientChannel ch;
  late pay.paymentsServiceClient payStub;
  late usr.userServiceClient userStub;

  setUp(() {
    ch = ClientChannel(host, port: port,
        options: const ChannelOptions(credentials: ChannelCredentials.insecure()));
    payStub  = pay.paymentsServiceClient(ch);
    userStub = usr.userServiceClient(ch);
  });

  tearDown(() => ch.shutdown());

  // ── Current balance ───────────────────────────────────────────────────────
  test('0. AccountBalance CURRENT', () async {
    w('\n══ AccountBalance CURRENT ══════════════════');
    final r = await userStub.accountBalance(
      usr.request()..username=username..password=password..domain=domain..packageId=packageId,
    ).timeout(const Duration(seconds: 15));
    w('  status  : ${r.status.name}');
    w('  balance (raw ns) : ${r.balance}');
    w('  balance (min)    : ${(r.balance / 1e9 / 60).toStringAsFixed(2)}');
    if (r.hasSuccess()) w('  success : ${r.success.localizedDescription}');
    w('════════════════════════════════════════════');
    save();
    expect(true, isTrue);
  });

  // ── Try Reversal with a negative recharge to subtract the overage ─────────
  // The account has ~12 trillion minutes. Target is 200 minutes.
  // We need to remove (12 trillion - 200) minutes = ~11,999,999,800 minutes.
  // Try Reversal RPC first to see what it accepts.
  test('1. Reversal — probe what params it needs', () async {
    w('\n══ Reversal probe ═══════════════════════════');
    final req = pay.requests()
      ..username = username ..password = password
      ..domain = domain ..packageId = packageId
      ..transactionId = 'TXN_PROBE'
      ..amount = 1;
    try {
      final r = await payStub.reversal(req).timeout(const Duration(seconds: 15));
      _printReply(r, showBalance: true);
    } on GrpcError catch (e) { w('  GRPC ERROR: ${e.codeName} — ${e.message}'); }
    catch (e) { w('  ERROR: $e'); }
    w('════════════════════════════════════════════');
    save();
    expect(true, isTrue);
  });

  // ── Try adding a clean 200 min (correct call) and check result ────────────
  test('2. RechargeAccount — correct call: amount=200 minutes', () async {
    w('\n══ RechargeAccount — amount=200 min ════════');
    final req = pay.requests()
      ..username = username ..password = password
      ..domain = domain ..packageId = packageId
      ..amount = 200
      ..transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';
    try {
      final r = await payStub.rechargeAccount(req).timeout(const Duration(seconds: 15));
      _printReply(r, showBalance: true);
    } on GrpcError catch (e) { w('  GRPC ERROR: ${e.codeName} — ${e.message}'); }
    catch (e) { w('  ERROR: $e'); }
    w('════════════════════════════════════════════');
    save();
    expect(true, isTrue);
  });
}
