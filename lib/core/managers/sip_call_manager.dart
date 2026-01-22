import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../features/call/presentation/views/call_view.dart';
import '../../features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import '../../features/recents/data/models/recent_call.dart';


class SipCallManager implements SipUaHelperListener {
  final SIPUAHelper _sipHelper;
  final GlobalKey<NavigatorState> navigatorKey;
  final DialpadViewModel _dialpadViewModel;

  SipCallManager(this._sipHelper, this.navigatorKey, this._dialpadViewModel) {
    _sipHelper.addSipUaHelperListener(this);
  }

  void dispose() {
    _sipHelper.removeSipUaHelperListener(this);
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    // Navigate to CallView on Incoming/Outgoing initiation
    if (callState.state == CallStateEnum.CALL_INITIATION) {
      if (call.direction.toString().toUpperCase().contains('INCOMING')) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => CallView(call: call)),
        );
      } else {
         navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => CallView(call: call)),
        );
         // Log Outgoing Call
         _logCall(call, isMissed: false, direction: 'outgoing');
      }
    }
    
    // Log Incoming calls when they end
    if (callState.state == CallStateEnum.ENDED || callState.state == CallStateEnum.FAILED) {
      if (call.direction.toString().toUpperCase().contains('INCOMING')) {
         bool isMissed = false;
         
         // Check cause for missed detection
         if (callState.cause != null) {
           final code = callState.cause!.cause;
           if (code == '487' || code == '408') { // 487: Request Terminated (Cancel), 408: Timeout
             isMissed = true;
           }
         }
         
         _logCall(call, isMissed: isMissed, direction: 'incoming');
      }
    }
  }
  
  Future<void> _logCall(Call call, {required bool isMissed, required String direction}) async {
    String number = call.remote_identity ?? 'Unknown';
    // Parse number to remove SIP URI scheme if cleaner display is desired
    // E.g. "User <sip:1001@domain>" -> "1001"
    if (number.contains('sip:')) {
      try {
        // Simple regex or split to extract user part
        final uri = Uri.parse(number.replaceAll('<', '').replaceAll('>', ''));
        // If it's sip:user@domain
        if (uri.scheme == 'sip') {
           final userInfo = uri.userInfo; // user part
           if (userInfo.isNotEmpty) {
             number = userInfo;
           }
        }
      } catch (e) {
        // Fallback to extraction via regex if Uri parsing fails (common with sip URIs)
        final match = RegExp(r'sip:([^@]+)@').firstMatch(number);
        if (match != null) {
          number = match.group(1)!;
        }
      }
    }
    // Further cleanup for display name part "Name <...>"
    if (number.contains('<')) {
       // Just take what's inside logic above might have failed if format was "Name <sip:...>" passing to Uri.parse
       // Let's rely on RegExp for "sip:user@" pattern which is robust
       final identity = call.remote_identity;
       if (identity != null) {
          final match = RegExp(r'sip:([^@>]+)').firstMatch(identity);
          if (match != null) {
            number = match.group(1)!;
          }
       }
    }
    
    await _dialpadViewModel.addRecentCall(RecentCall(
      number: number,
      timestamp: DateTime.now(),
      isMissed: isMissed, 
      direction: direction,
    ));
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void registrationStateChanged(RegistrationState state) {}

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewReinvite(ReInvite event) {}
}
