class RecentCall {
  final String? name;
  final String number;
  final DateTime timestamp;
  final bool isMissed;
  final String direction; // 'incoming' or 'outgoing'

  RecentCall({
    this.name,
    required this.number,
    required this.timestamp,
    this.isMissed = false,
    this.direction = 'outgoing',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'timestamp': timestamp.toIso8601String(),
      'isMissed': isMissed,
      'direction': direction,
    };
  }

  factory RecentCall.fromJson(Map<String, dynamic> json) {
    return RecentCall(
      name: json['name'],
      number: json['number'],
      timestamp: DateTime.parse(json['timestamp']),
      isMissed: json['isMissed'] ?? false,
      direction: json['direction'] ?? 'outgoing',
    );
  }
}
