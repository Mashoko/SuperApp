class SipConfig {
  const SipConfig({
    required this.websocketUrl,
    required this.origin,
    required this.transport,
    required this.port,
  });

  final String websocketUrl;
  final String origin;
  final String transport;
  final int port;
}

