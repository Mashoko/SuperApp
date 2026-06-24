import 'package:grpc/grpc.dart' as grpc;
import 'generated/payments.pbgrpc.dart';

export 'generated/payments.pbgrpc.dart' show reply, Status;

class PaymentsClient {
  static const String defaultProductionHost = 'wss.durihub.co.zw';
  static const String defaultServiceDomain  = 'localvoip.ai.co.zw';

  static const int insecurePort = 50000;
  static const int securePort   = 54000;

  final String packageId;
  final bool secure;
  final String host;
  final int port;
  final String serviceDomain;

  late final grpc.ClientChannel _channel;
  late final paymentsServiceClient _stub;

  PaymentsClient({
    required this.packageId,
    this.secure = false,
    String? host,
    int? port,
    String? serviceDomain,
  })  : host = host ?? defaultProductionHost,
        port = port ?? (secure ? securePort : insecurePort),
        serviceDomain = serviceDomain ?? defaultServiceDomain {
    _channel = grpc.ClientChannel(
      this.host,
      port: this.port,
      options: grpc.ChannelOptions(
        credentials: secure
            ? const grpc.ChannelCredentials.secure()
            : const grpc.ChannelCredentials.insecure(),
      ),
    );
    _stub = paymentsServiceClient(_channel);
  }

  requests _baseReq() => requests()
    ..packageId = packageId
    ..domain    = serviceDomain;

  /// Share airtime from the logged-in account to [receiver].
  Future<reply> shareAirtime({
    required String username,
    required String password,
    required String receiver,
    required double amount,
  }) async {
    final req = _baseReq()
      ..username = username
      ..password = password
      ..receiver = receiver
      ..amount   = amount;
    return _safe(() => _stub.shareAirtime(req), 'shareAirtime');
  }

  /// Fetch the dealer account balances for [username].
  Future<reply> dealerAccountBalances({
    required String username,
    required String password,
  }) async {
    final req = _baseReq()
      ..username = username
      ..password = password;
    return _safe(() => _stub.dealerAccountBalances(req), 'dealerAccountBalances');
  }

  /// Recharge account using a voucher PIN.
  /// [voucherPin] is optional — if omitted the server uses [amount] directly.
  /// [amount] is in minutes (server unit).
  Future<reply> rechargeAccount({
    required String username,
    required String password,
    String voucherPin = '',
    required String transactionId,
    double amount = 0,
  }) async {
    final req = _baseReq()
      ..username      = username
      ..password      = password
      ..voucherPin    = voucherPin
      ..transactionId = transactionId;
    if (amount > 0) req.amount = amount;
    return _safe(() => _stub.rechargeAccount(req), 'rechargeAccount');
  }

  /// Add [minutes] voice minutes directly to [username]'s account.
  Future<reply> addMinutes({
    required String username,
    required String password,
    required double minutes,
  }) =>
      rechargeAccount(
        username: username,
        password: password,
        amount: minutes,
        transactionId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

  Future<reply> _safe(Future<reply> Function() fn, String method) async {
    print('[gRPC-payments] → $method');
    try {
      final res = await fn();
      print('[gRPC-payments] ← $method | status: ${res.status}');
      return res;
    } catch (e) {
      print('[gRPC-payments] ← $method | ERROR: $e');
      return reply()
        ..status = Status.ERROR
        ..error  = (Error()
          ..localizedDescription = 'Client error'
          ..debugDescription     = e.toString());
    }
  }

  Future<void> close() async => _channel.shutdown();
}
