import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/services/calling_service.dart';
import 'package:mvvm_sip_demo/services/shopping_service.dart';
import 'package:mvvm_sip_demo/services/utility_bills_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final CallingService _callingService;
  final ShoppingService _shoppingService;
  final UtilityBillsService _utilityBillsService;

  DashboardViewModel(
    this._callingService,
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

  Future<void> loadDashboard(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      // Get calling stats
      final callStats = _callingService.getCallStatistics(userId);

      // Get shopping info
      final cart = _shoppingService.getCart(userId);
      final orders = _shoppingService.getOrders(userId: userId);

      // Get payments info
      final payments = _utilityBillsService.getPayments(userId);
      final totalSpent = payments.fold(0.0, (sum, p) => sum + p.amount);
      final lastPayment = payments.isNotEmpty ? payments.first : null;

      _dashboardData = {
        'user_id': userId,
        'calling': {
          'total_calls': callStats['total_calls'],
          'missed_calls': callStats['missed_calls'],
          'total_duration_seconds': callStats['total_duration_seconds'],
        },
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

