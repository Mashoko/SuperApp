class RecentCall {
  final String? name;
  final String number;
  final DateTime timestamp;
  final bool isMissed;
  final String direction; // 'incoming' or 'outgoing'
  /// Call length in seconds when known (optional for older stored rows).
  final int? durationSeconds;

  RecentCall({
    this.name,
    required this.number,
    required this.timestamp,
    this.isMissed = false,
    this.direction = 'outgoing',
    this.durationSeconds,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'timestamp': timestamp.toIso8601String(),
      'isMissed': isMissed,
      'direction': direction,
      'durationSeconds': durationSeconds,
    };
  }

  factory RecentCall.fromJson(Map<String, dynamic> json) {
    return RecentCall(
      name: json['name'],
      number: json['number'],
      timestamp: DateTime.parse(json['timestamp']),
      isMissed: json['isMissed'] ?? false,
      direction: json['direction'] ?? 'outgoing',
      durationSeconds: json['durationSeconds'] is int
          ? json['durationSeconds'] as int
          : (json['durationSeconds'] is num
              ? (json['durationSeconds'] as num).toInt()
              : null),
    );
  }
}
