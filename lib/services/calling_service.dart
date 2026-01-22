import 'package:mvvm_sip_demo/models/calling/call.dart';
import 'package:mvvm_sip_demo/models/calling/call_status.dart';

class CallingService {
  final Map<String, Call> _activeCalls = {};
  final List<Call> _callHistory = [];

  Call initiateCall(String callerId, String receiverId, {String callType = 'voice'}) {
    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}_$callerId';
    final call = Call(
      callId: callId,
      callerId: callerId,
      receiverId: receiverId,
      callType: callType,
      status: CallStatus.initiated,
    );
    _activeCalls[callId] = call;
    return call;
  }

  String answerCall(String callId) {
    final call = _activeCalls[callId];
    if (call != null) {
      final updatedCall = call.copyWith(
        status: CallStatus.connected,
        startTime: DateTime.now(),
      );
      _activeCalls[callId] = updatedCall;
      return 'Call $callId started';
    }
    return 'Call $callId not found';
  }

  String rejectCall(String callId) {
    final call = _activeCalls[callId];
    if (call != null) {
      final updatedCall = call.copyWith(
        status: CallStatus.rejected,
        endTime: DateTime.now(),
      );
      _callHistory.add(updatedCall);
      _activeCalls.remove(callId);
      return 'Call $callId rejected';
    }
    return 'Call $callId not found';
  }

  String endCall(String callId) {
    final call = _activeCalls[callId];
    if (call != null) {
      final endTime = DateTime.now();
      final duration = call.startTime != null
          ? endTime.difference(call.startTime!).inSeconds.toDouble()
          : 0.0;
      
      final updatedCall = call.copyWith(
        status: CallStatus.ended,
        endTime: endTime,
        duration: duration,
      );
      _callHistory.add(updatedCall);
      _activeCalls.remove(callId);
      return 'Call $callId ended. Duration: ${duration.toStringAsFixed(2)} seconds';
    }
    return 'Call $callId not found';
  }

  List<Call> getActiveCalls() {
    return _activeCalls.values.toList();
  }

  List<Call> getCallHistory({String? userId}) {
    if (userId == null) {
      return List.from(_callHistory);
    }
    return _callHistory
        .where((call) =>
            call.callerId == userId || call.receiverId == userId)
        .toList();
  }

  Map<String, dynamic> getCallStatistics(String userId) {
    final userCalls = getCallHistory(userId: userId);
    final totalCalls = userCalls.length;
    final totalDuration = userCalls.fold<double>(
        0.0, (sum, call) => sum + call.duration);
    final missedCalls = userCalls
        .where((call) => call.status == CallStatus.missed)
        .length;

    return {
      'user_id': userId,
      'total_calls': totalCalls,
      'total_duration_seconds': totalDuration,
      'missed_calls': missedCalls,
      'average_duration_seconds':
          totalCalls > 0 ? totalDuration / totalCalls : 0,
    };
  }
}

