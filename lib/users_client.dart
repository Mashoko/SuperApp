// users_client.dart
//
// REAL CatchApp gRPC client for the `userService` defined in users.proto.
// Uses the generated gRPC stubs in lib/generated/ and talks directly to the
// backend. No wrappers, no stubs.
//

import 'package:grpc/grpc.dart' as grpc;
import 'generated/users.pbgrpc.dart';

class UsersClient {
  // ---------------------------------------------------------------------------
  // Default API configuration (from CatchApp)
  // ---------------------------------------------------------------------------

  static const String defaultProductionHost = 'wss.durihub.co.zw';
  static const String defaultServiceDomain  = 'localvoip.ai.co.zw';

  static const int insecurePort = 50000;  // Testing
  static const int securePort   = 54000;  // Production (mTLS)

  static const int sipPort      = 6443;
  static const String sipTransport = 'WSS';

  // ---------------------------------------------------------------------------
  // Instance configuration
  // ---------------------------------------------------------------------------

  final String packageId;
  final bool secure;
  final String host;
  final int port;
  final String serviceDomain;

  late final grpc.ClientChannel _channel;
  late final userServiceClient _stub;

  UsersClient({
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

    _stub = userServiceClient(_channel);
  }

  // ---------------------------------------------------------------------------
  // Convenience getters for SIP / WebSocket
  // ---------------------------------------------------------------------------

  /// WSS endpoint for SIP (uses API/gRPC host, not the SIP realm domain).
  String get websocketUrl => 'wss://$host:$sipPort';
  String get originUrl    => 'sip:$serviceDomain';

  // ---------------------------------------------------------------------------
  // Internal helper to build a base request
  // ---------------------------------------------------------------------------

  request _baseReq() {
    return request()
      ..packageId = packageId
      ..domain    = serviceDomain;
  }

  // ---------------------------------------------------------------------------
  // API methods (ALL real gRPC calls)
  // ---------------------------------------------------------------------------

  /// Send SMS verification code.
  Future<response> sendVerificationCode({
    required String username,
    required String phone,
  }) async {
    final req = _baseReq()
      ..username = username
      ..token    = phone;

    return _safe(() => _stub.sendVerificationCode(req), 'sendVerificationCode');
  }

  /// Send WhatsApp OTP.
  Future<response> sendWhatsAppOTP({
    required String username,
    required String phone,
  }) async {
    final req = _baseReq()
      ..username = username
      ..token    = phone;

    return _safe(() => _stub.sendWhatsAppOTP(req), 'sendWhatsAppOTP');
  }

  /// Get allowed domain for this package ID.
  Future<response> getDomainForPackageID() async {
    final req = _baseReq();
    return _safe(() => _stub.getDomainForPackageID(req), 'getDomainForPackageID');
  }

  /// Get SIP websocket URL from the backend.
  Future<response> getWebsocketUrlFromApi() async {
    final req = _baseReq();
    return _safe(() => _stub.getWebsocketUrl(req), 'getWebsocketUrlFromApi');
  }

  /// Get SIP origin URL from the backend.
  Future<response> getOriginUrlFromApi() async {
    final req = _baseReq();
    return _safe(() => _stub.getOrignUrl(req), 'getOriginUrlFromApi');
  }

  /// Create or verify an account.
  ///
  /// [password], [email], [verificationCode], and [token] are optional because
  /// the backend can infer missing values for OTP verification flows.
  Future<response> createAccount({
    required String username,
    required String password,
    required String verificationCode,
  }) async {
    final req = _baseReq()
      ..username = username
      ..password = password
      ..verificationCode = verificationCode;

    return _safe(() => _stub.createAccount(req), 'createAccount');
  }

  /// Get account balance.
  Future<response> getAccountBalance({
    required String username,
    String? password,
  }) async {
    final req = _baseReq()
      ..username = username;

    if (password != null) {
      req.password = password;
    }

    return _safe(() => _stub.accountBalance(req), 'getAccountBalance');
  }

  /// Deregister (deactivate) an account.
  Future<response> deregisterAccount({
    required String username,
  }) async {
    final req = _baseReq()
      ..username = username;

    return _safe(() => _stub.deregisterAccount(req), 'deregisterAccount');
  }

  /// Get alias (CatchApp 86 number) for the user.
  Future<response> getAliasNumber({
    required String username,
    String? password,
  }) async {
    final req = _baseReq()
      ..username = username;

    if (password != null) {
      req.password = password;
    }

    return _safe(() => _stub.getAliasNumber(req), 'getAliasNumber');
  }

  // ---------------------------------------------------------------------------
  // Error-safe call wrapper
  // ---------------------------------------------------------------------------

  Future<response> _safe(Future<response> Function() fn, String method) async {
    print('[gRPC] → $method');
    try {
      final res = await fn();
      print('[gRPC] ← $method | status: ${res.status} | alias: ${res.alias} | balance: ${res.hasBalance() ? res.balance : '-'} | error: ${res.hasError() ? res.error.debugDescription : 'none'}');
      return res;
    } catch (e) {
      print('[gRPC] ← $method | ERROR: $e');
      return response()
        ..status = Status.ERROR
        ..error = (Error()
          ..localizedDescription = 'Local client error'
          ..debugDescription     = e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Shutdown
  // ---------------------------------------------------------------------------

  Future<void> close() async {
    await _channel.shutdown();
  }
}
