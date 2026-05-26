import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sip_ua/sip_ua.dart';

import '../../generated/users.pb.dart' as users;
import '../../users_client.dart';
import 'constants.dart';
import 'result.dart';

/// Shared SIP helpers for registration config and outbound calls.
class SipUtils {
  SipUtils._();

  static bool isReadyToCall(SIPUAHelper helper) =>
      helper.connected && helper.registered;

  /// User-facing message when [isReadyToCall] is false, or null if ready.
  static String? notReadyMessage(SIPUAHelper helper) {
    if (!helper.connected) {
      if (helper.connecting) {
        return 'Connecting to call server. Please wait a moment and try again.';
      }
      return 'Not connected to the call server. Check your network and try logging in again.';
    }
    if (!helper.registered) {
      final state = helper.registerState.state;
      if (helper.connecting) {
        return 'SIP registration in progress. Please wait a moment and try again.';
      }
      if (state == RegistrationStateEnum.REGISTRATION_FAILED) {
        return 'SIP registration failed. Please log in again.';
      }
      return 'Not registered for calls yet. Please wait or log in again.';
    }
    return null;
  }

  /// Resolves WSS URL from gRPC response.
  ///
  /// The API often returns the SIP realm (e.g. `localvoip.ai.co.zw`) in [domain],
  /// not the WSS proxy host (`wss.durihub.co.zw`). Pass [sipDomain] to avoid
  /// mistaking the realm for the websocket server.
  static String resolveWebSocketUrl({
    users.response? apiResponse,
    required String fallback,
    String? sipDomain,
  }) {
    if (apiResponse != null) {
      final info = apiResponse.info.information.trim();
      if (info.startsWith('ws://') || info.startsWith('wss://')) {
        return info;
      }

      final domain = apiResponse.domain.trim();
      if (domain.startsWith('ws://') || domain.startsWith('wss://')) {
        return domain;
      }

      // Bare hostname that is a dedicated WSS proxy (not the SIP realm).
      if (domain.isNotEmpty &&
          sipDomain != null &&
          domain != sipDomain &&
          !domain.startsWith('+')) {
        final withPort =
            domain.contains(':') ? domain : '$domain:${UsersClient.sipPort}';
        return 'wss://$withPort';
      }
    }
    return fallback;
  }

  /// Fetches domain, WebSocket URL, and Origin header for SIP registration.
  static Future<({String domain, String wsUrl, String originUrl})> fetchSipConfig(
    UsersClient usersClient,
  ) async {
    var domain = AppConstants.sipDomain;
    var wsUrl = AppConstants.websocketUrl;
    var originUrl = 'https://$domain';

    try {
      final domainResp = await usersClient.getDomainForPackageID();
      if (domainResp.domain.isNotEmpty) {
        domain = domainResp.domain;
      }

      final wsResp = await usersClient.getWebsocketUrlFromApi();
      wsUrl = resolveWebSocketUrl(
        apiResponse: wsResp,
        sipDomain: domain,
        fallback: AppConstants.websocketUrl,
      );

      final originResp = await usersClient.getOriginUrlFromApi();
      if (originResp.info.information.isNotEmpty) {
        originUrl = originResp.info.information;
      } else if (originResp.domain.isNotEmpty) {
        originUrl = originResp.domain;
      }
    } catch (_) {
      // Use defaults already set above.
    }

    return (domain: domain, wsUrl: wsUrl, originUrl: originUrl);
  }

  static Future<void> safeDisposeMediaStream(MediaStream? stream) async {
    if (stream == null) return;
    try {
      for (final track in stream.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      await stream.dispose();
    } catch (_) {
      // Native stream may already have been released by WebRTC/SIP stack.
    }
  }

  /// Acquires mic (and optionally camera), then starts an outbound SIP call.
  static Future<Result<void>> placeOutgoingCall(
    SIPUAHelper helper,
    String destination, {
    bool voiceOnly = true,
  }) async {
    final blocked = notReadyMessage(helper);
    if (blocked != null) {
      return Failure(blocked);
    }

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        return const Failure(
          'Microphone permission is required to make calls.',
        );
      }
    }

    MediaStream? mediaStream;
    try {
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': voiceOnly
            ? false
            : {
                'mandatory': <String, dynamic>{
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
              },
      };

      mediaStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      final started = await helper.call(
        destination,
        voiceOnly: voiceOnly,
        mediaStream: mediaStream,
      );

      if (!started) {
        await safeDisposeMediaStream(mediaStream);
        return const Failure(
          'Could not start the call. The phone service is not connected.',
        );
      }

      return const Success(null);
    } catch (e) {
      await safeDisposeMediaStream(mediaStream);
      return Failure('Failed to make call: $e');
    }
  }
}
