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

  String get websocketUrl => 'wss://$serviceDomain:$sipPort';
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

    return _safe(() => _stub.sendVerificationCode(req));
  }

  /// Send WhatsApp OTP.
  Future<response> sendWhatsAppOTP({
    required String username,
    required String phone,
  }) async {
    final req = _baseReq()
      ..username = username
      ..token    = phone;

    return _safe(() => _stub.sendWhatsAppOTP(req));
  }

  /// Get allowed domain for this package ID.
  Future<response> getDomainForPackageID() async {
    final req = _baseReq();
    return _safe(() => _stub.getDomainForPackageID(req));
  }

  /// Get SIP websocket URL from the backend.
  Future<response> getWebsocketUrlFromApi() async {
    final req = _baseReq();
    return _safe(() => _stub.getWebsocketUrl(req));
  }

  /// Get SIP origin URL from the backend.
  Future<response> getOriginUrlFromApi() async {
    final req = _baseReq();
    return _safe(() => _stub.getOrignUrl(req));
  }

  /// Create a new account.
  Future<response> createAccount({
    required String username,
    required String password,
    required String email,
  }) async {
    final req = _baseReq()
      ..username = username
      ..password = password
      ..email    = email;

    return _safe(() => _stub.createAccount(req));
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

    return _safe(() => _stub.accountBalance(req));
  }

  /// Deregister (deactivate) an account.
  Future<response> deregisterAccount({
    required String username,
  }) async {
    final req = _baseReq()
      ..username = username;

    return _safe(() => _stub.deregisterAccount(req));
  }

  /// Get alias (CatchApp 86 number) for the user.
  Future<response> getAliasNumber({
    required String username,
  }) async {
    final req = _baseReq()
      ..username = username;

    return _safe(() => _stub.getAliasNumber(req));
  }

  // ---------------------------------------------------------------------------
  // Error-safe call wrapper
  // ---------------------------------------------------------------------------

  Future<response> _safe(Future<response> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      // If anything local (network, TLS, etc.) fails, return a synthetic error
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
