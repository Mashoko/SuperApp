class AppConstants {
  // SIP Configuration
  static const String websocketUrl = 'wss://wss.durihub.co.zw:6443';
  static const String sipDomain = 'localvoip.ai.co.zw';
  static const String port = '6443';
  
  // SIP Defaults (for backward compatibility)
  static const String defaultWsUrl = websocketUrl;
  static const String defaultPort = port;
  static const String defaultDestination = 'sip:user@$sipDomain';

  // SharedPreferences Keys
  static const String keyWsUri = 'ws_uri';
  static const String keySipUri = 'sip_uri';
  static const String keyDisplayName = 'display_name';
  static const String keyPassword = 'password';
  static const String keyAuthUser = 'auth_user';
  static const String keyPort = 'port';
  static const String keyDestination = 'dest';
}

