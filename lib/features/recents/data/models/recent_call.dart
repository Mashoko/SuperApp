import 'call_log_status.dart';

class RecentCall {
  final String? name;
  final String number;
  final DateTime timestamp;
  final CallLogStatus status;
  final String direction; // 'incoming' or 'outgoing'
  /// Call length in seconds when known (optional for older stored rows).
  final int? durationSeconds;

  RecentCall({
    this.name,
    required this.number,
    required this.timestamp,
    this.status = CallLogStatus.completed,
    this.direction = 'outgoing',
    this.durationSeconds,
  });

  /// Derived for backward compatibility with existing UI code that reads
  /// isMissed directly (call_history_widget.dart, recents_view.dart, etc.).
  bool get isMissed => status == CallLogStatus.missed;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'direction': direction,
      'durationSeconds': durationSeconds,
    };
  }

  factory RecentCall.fromJson(Map<String, dynamic> json) {
    return RecentCall(
      name: json['name'],
      number: json['number'],
      timestamp: DateTime.parse(json['timestamp']),
      status: _resolveStoredStatus(json),
      direction: json['direction'] ?? 'outgoing',
      durationSeconds: json['durationSeconds'] is int
          ? json['durationSeconds'] as int
          : (json['durationSeconds'] is num
              ? (json['durationSeconds'] as num).toInt()
              : null),
    );
  }

  /// Already-stored rows from before this field existed have no `status`
  /// key — only the legacy `isMissed` bool. Fall back to deriving a
  /// best-effort status from it so old rows keep displaying sensibly.
  static CallLogStatus _resolveStoredStatus(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    if (statusName != null) {
      return CallLogStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => CallLogStatus.completed,
      );
    }
    final legacyIsMissed = json['isMissed'] == true;
    return legacyIsMissed ? CallLogStatus.missed : CallLogStatus.completed;
  }
}
