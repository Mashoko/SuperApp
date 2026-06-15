import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/banner.dart';
import 'package:mvvm_sip_demo/services/shopping_service.dart';

class ShoppingViewModel extends ChangeNotifier {
  final ShoppingService _service;

  ShoppingViewModel(this._service);

  List<Product> _products = [];
  Map<String, dynamic> _cart = {};
  List<Order> _orders = [];
  List<Banner> _banners = [];
  List<String> _categories = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  String? _errorMessage;

  String _userId = '';
  String _selectedCategory = 'All';
  String _searchQuery = '';

  int _page = 1;
  int _totalPages = 1;

  String? _discountCode;
  double _discountAmount = 0.0;
  bool _isCheckingVoucher = false;

  List<String> _recentSearches = [];

  // ── Getters ──────────────────────────────────────────────────────────────

  List<Product> get products => _products;
  Map<String, dynamic> get cart => _cart;
  List<Order> get orders => _orders;
  List<Banner> get banners => _banners;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isMoreLoading => _isMoreLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  String get userId => _userId;

  String? get discountCode => _discountCode;
  double get discountAmount => _discountAmount;
  bool get isCheckingVoucher => _isCheckingVoucher;
  double get total =>
      ((_cart['total'] ?? 0.0) as num).toDouble() - _discountAmount;

  List<String> get recentSearches => _recentSearches;

  // ── Private helpers ───────────────────────────────────────────────────────

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setMoreLoading(bool v) { _isMoreLoading = v; notifyListeners(); }
  void _setError(String? e) { _errorMessage = e; notifyListeners(); }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> loadProducts({String? category, String? search}) async {
    try {
      _setLoading(true);
      _setError(null);
      _page = 1;
      _totalPages = 1;

      await Future.wait([loadCategories(), loadBanners()]);

      final cat = category ?? _selectedCategory;
      final q = search ?? _searchQuery;

      final result = await _service.fetchProducts(
        page: 1,
        category: cat,
        search: q.isEmpty ? null : q,
      );

      _products = result.products;
      _totalPages = result.totalPages;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load products. Check your connection and try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMoreProducts() async {
    if (_isLoading || _isMoreLoading || _page >= _totalPages) return;
    try {
      _setMoreLoading(true);
      _page++;
      final result = await _service.fetchProducts(
        page: _page,
        category: _selectedCategory,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      _products.addAll(result.products);
      notifyListeners();
    } catch (e) {
      _page--;
      _setError('Failed to load more products.');
    } finally {
      _setMoreLoading(false);
    }
  }

  Future<void> loadBanners() async {
    try {
      _banners = await _service.fetchBanners();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadCategories() async {
    try {
      final loaded = await _service.fetchCategories();
      _categories = loaded.isNotEmpty ? ['All', ...loaded] : ['All'];
      if (!_categories.contains(_selectedCategory)) _selectedCategory = 'All';
      notifyListeners();
    } catch (_) {}
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _searchQuery = '';
    notifyListeners();
    loadProducts(category: category);
  }

  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    _selectedCategory = 'All';
    notifyListeners();
    await loadProducts(search: query);
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
    loadProducts();
  }

  void addRecentSearch(String term) {
    if (term.isEmpty) return;
    _recentSearches.remove(term);
    _recentSearches.insert(0, term);
    if (_recentSearches.length > 10) _recentSearches = _recentSearches.sublist(0, 10);
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }

  // ── Cart ──────────────────────────────────────────────────────────────────

  Future<void> loadCart(String userId) async {
    try {
      _userId = userId;
      _cart = await _service.fetchCart(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load cart.');
    }
  }

  Future<void> addToCart(String userId, String productId,
      {int quantity = 1}) async {
    try {
      _userId = userId;
      _setError(null);
      _cart = await _service.addToCart(userId, productId, quantity: quantity);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add to cart.');
    }
  }

  Future<void> updateCartQuantity(
      String userId, String productId, int quantity) async {
    try {
      _setError(null);
      _cart = await _service.updateCartQuantity(userId, productId, quantity);
      notifyListeners();
    } catch (e) {
      _setError('Failed to update cart.');
    }
  }

  Future<void> removeFromCart(String userId, String productId) async {
    try {
      _setError(null);
      _cart = await _service.removeFromCart(userId, productId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove from cart.');
    }
  }

  void clearCart() {
    _cart = {};
    _discountCode = null;
    _discountAmount = 0.0;
    notifyListeners();
  }

  int getProductQuantity(String productId) {
    if (_cart['items'] == null) return 0;
    final items = _cart['items'] as List<dynamic>;
    try {
      final item = items.firstWhere(
        (i) => i['product']?['_id']?.toString() == productId ||
               i['product']?['product_id']?.toString() == productId,
        orElse: () => null,
      );
      return (item != null) ? (item['quantity'] as int? ?? 0) : 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Voucher ───────────────────────────────────────────────────────────────

  Future<void> applyDiscount(String code) async {
    try {
      _isCheckingVoucher = true;
      _setError(null);
      notifyListeners();

      final cartTotal = (_cart['total'] as num?)?.toDouble() ?? 0.0;
      final result = await _service.validateVoucher(code, cartTotal);

      if (result['valid'] == true) {
        _discountCode = result['code'];
        _discountAmount = (result['discount_amount'] as num).toDouble();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        _errorMessage = null;
        notifyListeners();
      });
    } finally {
      _isCheckingVoucher = false;
      notifyListeners();
    }
  }

  void removeDiscount() {
    _discountCode = null;
    _discountAmount = 0.0;
    notifyListeners();
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  Future<bool> placeOrder(
    String userId,
    String shippingAddress, {
    String? transactionId,
    String paymentStatus = 'pending',
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final order = await _service.placeOrder(
        userId,
        shippingAddress,
        transactionId: transactionId,
        paymentStatus: paymentStatus,
        discountAmount: _discountAmount,
        discountCode: _discountCode,
        cartSnapshot: Map<String, dynamic>.from(_cart),
      );

      if (order != null) {
        clearCart();
        await _service.clearCart(userId);
        await loadOrders(userId: userId);
        return true;
      } else {
        _setError('Failed to place order. Please try again.');
        return false;
      }
    } catch (e) {
      _setError('Failed to place order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadOrders({String? userId}) async {
    try {
      _setLoading(true);
      _setError(null);
      final uid = userId ?? _userId;
      if (uid.isEmpty) return;
      _orders = await _service.fetchOrders(uid);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load orders.');
    } finally {
      _setLoading(false);
    }
  }
}
