import '../../domain/entities/sip_user.dart';
import 'package:sip_ua/sip_ua.dart';

class SipUserModel extends SipUser {
  SipUserModel({
    required super.port,
    required super.displayName,
    required super.password,
    required super.authUser,
    required super.selectedTransport,
    super.wsExtraHeaders,
    super.wsUrl,
    super.sipUri,
  });

  factory SipUserModel.fromJson(Map<String, dynamic> json) {
    return SipUserModel(
      port: json['port'] as String,
      displayName: json['display_name'] as String,
      password: json['password'] as String,
      authUser: json['auth_user'] as String,
      selectedTransport: TransportType.values.firstWhere(
        (e) => e.toString() == json['selected_transport'],
        orElse: () => TransportType.TCP,
      ),
      wsExtraHeaders: json['ws_extra_headers'] != null
          ? Map<String, String>.from(json['ws_extra_headers'] as Map)
          : null,
      wsUrl: json['ws_url'] as String?,
      sipUri: json['sip_uri'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'port': port,
      'display_name': displayName,
      'password': password,
      'auth_user': authUser,
      'selected_transport': selectedTransport.toString(),
      'ws_extra_headers': wsExtraHeaders,
      'ws_url': wsUrl,
      'sip_uri': sipUri,
    };
  }
}

