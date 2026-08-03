import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/call_log_status.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/recent_call.dart';

void main() {
  group('DashboardViewModel.callStatsFrom', () {
    test('counts total calls, missed calls, and sums durations', () {
      final recents = [
        RecentCall(
          number: '1',
          timestamp: DateTime(2026, 1, 1),
          status: CallLogStatus.completed,
          durationSeconds: 60,
        ),
        RecentCall(
          number: '2',
          timestamp: DateTime(2026, 1, 2),
          status: CallLogStatus.missed,
          durationSeconds: null,
        ),
        RecentCall(
          number: '3',
          timestamp: DateTime(2026, 1, 3),
          status: CallLogStatus.declined,
          durationSeconds: null,
        ),
        RecentCall(
          number: '4',
          timestamp: DateTime(2026, 1, 4),
          status: CallLogStatus.completed,
          durationSeconds: 30,
        ),
      ];

      final stats = DashboardViewModel.callStatsFrom(recents);

      expect(stats['total_calls'], 4);
      expect(stats['missed_calls'], 1);
      expect(stats['total_duration_seconds'], 90);
    });

    test('handles an empty list', () {
      final stats = DashboardViewModel.callStatsFrom(const []);

      expect(stats['total_calls'], 0);
      expect(stats['missed_calls'], 0);
      expect(stats['total_duration_seconds'], 0);
    });
  });
}
