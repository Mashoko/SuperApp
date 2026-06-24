import 'package:flutter/foundation.dart';
import '../../../../core/services/otp_auth_service.dart';
import '../../../../services/shopping_service.dart';
import '../../../../services/shipping_address_service.dart';
import '../../../../models/shopping/order.dart';
import '../../../../models/shopping/order_status.dart';

class ProfileSummaryViewModel extends ChangeNotifier {
  final OtpAuthService _authService;
  final ShoppingService _shoppingService;
  final ShippingAddressService _addressService;

  ProfileSummaryViewModel(
      this._authService, this._shoppingService, this._addressService);

  bool _loading = false;
  int _orderCount = 0;
  int _activeOrderCount = 0;
  int _wishlistCount = 0;
  String? _defaultAddress;
  DateTime? _lastUpdated;

  bool get loading => _loading;
  int get orderCount => _orderCount;
  int get activeOrderCount => _activeOrderCount;
  int get wishlistCount => _wishlistCount;
  String? get defaultAddress => _defaultAddress;
  DateTime? get lastUpdated => _lastUpdated;

  bool get hasActiveOrders => _activeOrderCount > 0;
  bool get hasWishlistItems => _wishlistCount > 0;

  String get orderSubtitle {
    if (_loading) return 'Loading…';
    if (_orderCount == 0) return 'No orders yet';
    final label = _orderCount == 1 ? 'order' : 'orders';
    final activePart =
        _activeOrderCount > 0 ? ' · $_activeOrderCount active' : '';
    return '$_orderCount $label$activePart';
  }

  String get wishlistSubtitle {
    if (_loading) return 'Loading…';
    if (_wishlistCount == 0) return 'No saved items';
    return '$_wishlistCount saved item${_wishlistCount != 1 ? 's' : ''}';
  }

  String get addressSubtitle {
    if (_loading) return 'Loading…';
    if (_defaultAddress == null) return 'No addresses saved';
    return 'Default: $_defaultAddress';
  }

  // No payment methods API yet — placeholder
  String get paymentSubtitle => 'No methods linked';

  Future<void> load() async {
    final creds = await _authService.getStoredCredentials();
    final userId = creds?['username'];
    if (userId == null || userId.isEmpty) return;

    _loading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _shoppingService.fetchOrders(userId),
        _shoppingService.fetchWishlistCount(userId),
        _addressService.fetchAddresses(userId),
      ]);

      final orders = results[0] as List<Order>;
      final wishlistCount = results[1] as int;
      final addresses = results[2] as List<ShippingAddress>;

      _orderCount = orders.length;
      _activeOrderCount = orders.where((o) {
        return o.status == OrderStatus.pending ||
            o.status == OrderStatus.confirmed ||
            o.status == OrderStatus.processing ||
            o.status == OrderStatus.shipped;
      }).length;
      _wishlistCount = wishlistCount;

      final defaultAddr =
          addresses.where((a) => a.isDefault).isNotEmpty
              ? addresses.firstWhere((a) => a.isDefault)
              : addresses.isNotEmpty
                  ? addresses.first
                  : null;

      if (defaultAddr != null) {
        final city =
            defaultAddr.city.isNotEmpty ? ', ${defaultAddr.city}' : '';
        _defaultAddress = '${defaultAddr.address}$city';
      } else {
        _defaultAddress = null;
      }

      _lastUpdated = DateTime.now();
    } catch (_) {}

    _loading = false;
    notifyListeners();
  }
}
