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
  bool _isLoading = false;
  String? _errorMessage;

  String _selectedCategory = 'All'; // Default to 'All' or first loaded
  List<String> _categories = [];
  bool _isCategoriesLoading = false;
  ProductViewMode _viewMode = ProductViewMode.extraSmall;
  List<String> _recentSearches = [];

  int _page = 1;
  int _totalPages = 1;
  bool _isMoreLoading = false;

  List<Product> get products => _products;
  
  Map<String, dynamic> get cart => _cart;
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isMoreLoading => _isMoreLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  List<String> get categories => _categories;
  ProductViewMode get viewMode => _viewMode;
  List<String> get recentSearches => _recentSearches;

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
    loadProducts(category: category);
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
  
  void _setMoreLoading(bool value) {
    _isMoreLoading = value;
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
      
      _page = 1;
      _totalPages = 1; // Reset to ensure we can try fetching
      
      // Load dependencies
      await loadCategories(); 
      await loadBanners();
      
      // Fetch Page 1
      final result = await _service.fetchProducts(page: 1, category: category ?? _selectedCategory);
      
      _products = result.products;
      _totalPages = result.totalPages;
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load products: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMoreProducts() async {
    if (_isLoading || _isMoreLoading || _page >= _totalPages) return;
    
    try {
      _setMoreLoading(true);
      _page++;
      
      final result = await _service.fetchProducts(page: _page, category: _selectedCategory);
      
      _products.addAll(result.products);
      // _totalPages = result.totalPages; // Should be same, but can update
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load more products: $e');
      _page--; // Revert page on failure
    } finally {
      _setMoreLoading(false);
    }
  }

  List<Banner> _banners = [];
  List<Banner> get banners => _banners;

  Future<void> loadBanners() async {
    try {
      _banners = await _service.fetchBanners();
      notifyListeners();
    } catch (e) {
      print('VM: Error loading banners $e');
    }
  }

  Future<void> loadCategories() async {
    try {
      // _isCategoriesLoading = true;
      // notifyListeners();
      final loadedCats = await _service.fetchCategories();
      if (loadedCats.isNotEmpty) {
        _categories = ['All', ...loadedCats]; // Add 'All' as the default
      } else {
        _categories = ['All']; 
      }
      
      // If selected category is no longer valid, reset to All
      if (!_categories.contains(_selectedCategory)) {
        _selectedCategory = 'All';
      }
      
      notifyListeners();
    } catch (e) {
      print('VM: Error loading categories $e');
    }
  }

  Future<void> addToCart(String userId, String productId, {int quantity = 1}) async {
    try {
      _setError(null);
      _service.addToCart(userId, productId, quantity: quantity);
      await loadCart(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add to cart: $e');
    }
  }



  Future<void> updateCartQuantity(String userId, String productId, int quantity) async {
    try {
      _setError(null);
      _service.updateCartQuantity(userId, productId, quantity);
      await loadCart(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to update cart: $e');
    }
  }
  
  int getProductQuantity(String productId) {
    if (_cart['items'] == null) return 0;
    
    final items = _cart['items'] as List<dynamic>;
    try {
      final item = items.firstWhere(
        (item) => item['product_id'] == productId || item['product']['product_id'] == productId,
        orElse: () => null,
      );
      
      if (item != null) {
        return item['quantity'] as int;
      }
    } catch (e) {
      // Handle potential structure mismatch gracefully
      return 0;
    }
    return 0;
  }

  Future<void> removeFromCart(String userId, String productId) async {
    try {
      _setError(null);
      _service.removeFromCart(userId, productId);
      await loadCart(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove from cart: $e');
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

