import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/recent_call.dart';
import 'package:mvvm_sip_demo/services/shopping_service.dart';
import 'package:mvvm_sip_demo/services/utility_bills_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final DialpadViewModel _dialpadViewModel;
  final ShoppingService _shoppingService;
  final UtilityBillsService _utilityBillsService;

  DashboardViewModel(
    this._dialpadViewModel,
    this._shoppingService,
    this._utilityBillsService,
  );

  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> get dashboardData => _dashboardData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Aggregates real call-log entries into the same shape the dashboard
  /// card renders. Static and pure so it's testable without constructing
  /// a full DashboardViewModel or its other service dependencies.
  static Map<String, dynamic> callStatsFrom(List<RecentCall> recents) {
    final totalDuration = recents.fold<int>(
      0,
      (sum, call) => sum + (call.durationSeconds ?? 0),
    );
    final missedCalls = recents.where((call) => call.isMissed).length;

    return {
      'total_calls': recents.length,
      'missed_calls': missedCalls,
      'total_duration_seconds': totalDuration,
    };
  }

  Future<void> loadDashboard(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      // Get calling stats from real call history.
      await _dialpadViewModel.loadRecents();
      final callStats = callStatsFrom(_dialpadViewModel.recents);

      // Get shopping info
      final cart = await _shoppingService.fetchCart(userId);
      final orders = await _shoppingService.fetchOrders(userId);

      // Get payments info
      final payments = _utilityBillsService.getPayments(userId);
      final totalSpent = payments.fold(0.0, (sum, p) => sum + p.amount);
      final lastPayment = payments.isNotEmpty ? payments.first : null;

      _dashboardData = {
        'user_id': userId,
        'calling': callStats,
        'shopping': {
          'cart_items': cart['item_count'],
          'cart_total': cart['total'],
          'total_orders': orders.length,
        },
        'payments': {
          'total_spent': totalSpent,
          'total_payments': payments.length,
          'last_payment_amount': lastPayment?.amount ?? 0.0,
        },
      };

      notifyListeners();
    } catch (e) {
      _setError('Failed to load dashboard: $e');
    } finally {
      _setLoading(false);
    }
  }
}

