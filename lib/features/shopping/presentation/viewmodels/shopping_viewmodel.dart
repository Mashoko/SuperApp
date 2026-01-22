import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/services/shopping_service.dart';

class ShoppingViewModel extends ChangeNotifier {
  final ShoppingService _service;

  ShoppingViewModel(this._service);

  List<Product> _products = [];
  Map<String, dynamic> _cart = {};
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _selectedCategory = 'Popular';
  final List<String> _categories = ['Popular', 'Produce', 'Butcher', 'Bakery', 'Staples', 'Dairy', 'Infants', 'Beverages', 'Household', 'Snacks', 'Sanitary', 'Pets'];
  ProductViewMode _viewMode = ProductViewMode.extraSmall;
  List<String> _recentSearches = [];

  List<Product> get products {
    if (_selectedCategory == 'Popular') {
      return _products;
    }
    return _products.where((p) => p.category == _selectedCategory).toList();
  }
  
  Map<String, dynamic> get cart => _cart;
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  List<String> get categories => _categories;
  ProductViewMode get viewMode => _viewMode;
  List<String> get recentSearches => _recentSearches;

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void cycleViewMode() {
    // Enforce extra small view mode
    _viewMode = ProductViewMode.extraSmall;
    notifyListeners();
  }

  void addRecentSearch(String term) {
    if (term.isEmpty) return;
    
    // Remove if exists to move to top
    _recentSearches.remove(term);
    
    // Add to top
    _recentSearches.insert(0, term);
    
    // Limit to 10
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  Future<void> loadProducts({String? category}) async {
    try {
      _setLoading(true);
      _setError(null);
      _products = _service.getProducts(category: category);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load products: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addToCart(String userId, String productId, {int quantity = 1}) async {
    try {
      _setLoading(true);
      _setError(null);
      _service.addToCart(userId, productId, quantity: quantity);
      await loadCart(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add to cart: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeFromCart(String userId, String productId) async {
    try {
      _setLoading(true);
      _setError(null);
      _service.removeFromCart(userId, productId);
      await loadCart(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove from cart: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadCart(String userId) async {
    try {
      _cart = _service.getCart(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load cart: $e');
    }
  }

  Future<bool> placeOrder(String userId, String shippingAddress) async {
    try {
      _setLoading(true);
      _setError(null);
      final order = _service.placeOrder(userId, shippingAddress);
      if (order != null) {
        await loadCart(userId);
        await loadOrders(userId: userId);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to place order. Cart may be empty or stock insufficient.');
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
      _orders = _service.getOrders(userId: userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load orders: $e');
    } finally {
      _setLoading(false);
    }
  }
}

