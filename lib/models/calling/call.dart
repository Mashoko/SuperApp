import 'package:mvvm_sip_demo/models/calling/call_status.dart';

class Call {
  final String callId;
  final String callerId;
  final String receiverId;
  final String callType; // "voice" or "video"
  final CallStatus status;
  final DateTime? startTime;
  final DateTime? endTime;
  final double duration; // in seconds

  Call({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    this.callType = 'voice',
    this.status = CallStatus.initiated,
    this.startTime,
    this.endTime,
    this.duration = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'caller_id': callerId,
      'receiver_id': receiverId,
      'call_type': callType,
      'status': status.value,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration': duration,
    };
  }

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      callId: json['call_id'] ?? '',
      callerId: json['caller_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      callType: json['call_type'] ?? 'voice',
      status: CallStatusExtension.fromString(json['status'] ?? 'initiated'),
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : null,
      endTime:
          json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      duration: (json['duration'] ?? 0).toDouble(),
    );
  }

  Call copyWith({
    String? callId,
    String? callerId,
    String? receiverId,
    String? callType,
    CallStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    double? duration,
  }) {
    return Call(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      receiverId: receiverId ?? this.receiverId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
    );
  }
}

