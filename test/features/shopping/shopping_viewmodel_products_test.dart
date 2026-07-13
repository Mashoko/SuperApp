import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/models/shopping/banner.dart' as shopping_banner;
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/services/shopping_service.dart';

Product _product(String id, {String category = 'General'}) {
  return Product(productId: id, name: 'Product $id', price: 10.0, category: category);
}

class FakeShoppingService implements ShoppingService {
  bool trendingOk = true;
  bool recommendedOk = true;
  List<Product> trendingResult = [_product('t1')];
  List<Product> recommendedResult = [_product('r1')];
  List<Product> wishlistResult = [];
  bool failAddToWishlist = false;
  bool failRemoveFromWishlist = false;

  @override
  Future<({List<Product> products, int totalPages, bool ok})> fetchTrendingProducts(
      {int page = 1, int limit = 10}) async {
    if (!trendingOk) return (products: <Product>[], totalPages: 0, ok: false);
    return (products: trendingResult, totalPages: 1, ok: true);
  }

  @override
  Future<({List<Product> products, int totalPages, bool ok})> fetchRecommendedProducts(
      {required String userId, int page = 1, int limit = 10}) async {
    if (!recommendedOk) return (products: <Product>[], totalPages: 0, ok: false);
    return (products: recommendedResult, totalPages: 1, ok: true);
  }

  @override
  Future<List<Product>> fetchWishlist(String userId) async => wishlistResult;

  @override
  Future<void> addToWishlist(String userId, String productId) async {
    if (failAddToWishlist) throw Exception('failed to add');
  }

  @override
  Future<void> removeFromWishlist(String userId, String productId) async {
    if (failRemoveFromWishlist) throw Exception('failed to remove');
  }

  @override
  Future<({List<Product> products, int totalPages, bool ok})> fetchProducts(
      {int page = 1, int limit = 10, String? category, String? search}) async {
    return (products: <Product>[], totalPages: 1, ok: true);
  }

  @override
  Future<List<String>> fetchCategories() async => [];

  @override
  Future<List<shopping_banner.Banner>> fetchBanners() async => [];

  @override
  Product? getProduct(String productId) => null;

  @override
  Future<Map<String, dynamic>> fetchCart(String userId) async =>
      {'items': [], 'total': 0.0};

  @override
  Future<Map<String, dynamic>> addToCart(String userId, String productId,
      {int quantity = 1}) async => {'items': [], 'total': 0.0};

  @override
  Future<Map<String, dynamic>> updateCartQuantity(
      String userId, String productId, int quantity) async => {'items': [], 'total': 0.0};

  @override
  Future<Map<String, dynamic>> removeFromCart(String userId, String productId) async =>
      {'items': [], 'total': 0.0};

  @override
  Future<void> clearCart(String userId) async {}

  @override
  Future<Order?> placeOrder(String userId, String shippingAddress,
      {String? transactionId,
      String paymentStatus = 'pending',
      double discountAmount = 0.0,
      String? discountCode,
      required Map<String, dynamic> cartSnapshot}) async => null;

  @override
  Future<List<Order>> fetchOrders(String userId) async => [];

  @override
  Future<int> fetchWishlistCount(String userId) async => wishlistResult.length;

  @override
  Future<Map<String, dynamic>> validateVoucher(String code, double total) async => {};
}

void main() {
  group('loadTrendingProducts', () {
    test('populates trendingProducts on success', () async {
      final vm = ShoppingViewModel(FakeShoppingService());

      await vm.loadTrendingProducts();

      expect(vm.trendingProducts, hasLength(1));
      expect(vm.trendingLoading, false);
      expect(vm.trendingError, isNull);
    });

    test('sets trendingError (not just an empty list) on failure', () async {
      final fake = FakeShoppingService()..trendingOk = false;
      final vm = ShoppingViewModel(fake);

      await vm.loadTrendingProducts();

      expect(vm.trendingError, isNotNull);
      expect(vm.trendingProducts, isEmpty);
    });
  });

  group('loadRecommendedProducts', () {
    test('populates recommendedProducts on success', () async {
      final vm = ShoppingViewModel(FakeShoppingService());

      await vm.loadRecommendedProducts('user1');

      expect(vm.recommendedProducts, hasLength(1));
      expect(vm.recommendedError, isNull);
    });

    test('sets recommendedError on failure, independently of trending', () async {
      final fake = FakeShoppingService()..recommendedOk = false;
      final vm = ShoppingViewModel(fake);

      await vm.loadTrendingProducts();
      await vm.loadRecommendedProducts('user1');

      expect(vm.recommendedError, isNotNull);
      expect(vm.trendingError, isNull, reason: 'a recommended failure must not affect trending');
      expect(vm.trendingProducts, hasLength(1));
    });
  });

  group('wishlist', () {
    test('loadWishlist populates wishlistProductIds and isWishlisted reflects it', () async {
      final fake = FakeShoppingService()..wishlistResult = [_product('w1')];
      final vm = ShoppingViewModel(fake);

      await vm.loadWishlist('user1');

      expect(vm.isWishlisted('w1'), true);
      expect(vm.isWishlisted('other'), false);
    });

    test('toggleWishlist optimistically adds and keeps the change on success', () async {
      final vm = ShoppingViewModel(FakeShoppingService());

      await vm.toggleWishlist('user1', 'p1');

      expect(vm.isWishlisted('p1'), true);
    });

    test('toggleWishlist reverts the optimistic add on failure', () async {
      final fake = FakeShoppingService()..failAddToWishlist = true;
      final vm = ShoppingViewModel(fake);

      await vm.toggleWishlist('user1', 'p1');

      expect(vm.isWishlisted('p1'), false);
    });

    test('toggleWishlist removes an already-wishlisted product optimistically', () async {
      final fake = FakeShoppingService()..wishlistResult = [_product('w1')];
      final vm = ShoppingViewModel(fake);
      await vm.loadWishlist('user1');

      await vm.toggleWishlist('user1', 'w1');

      expect(vm.isWishlisted('w1'), false);
    });

    test('toggleWishlist reverts the optimistic removal on failure', () async {
      final fake = FakeShoppingService()
        ..wishlistResult = [_product('w1')]
        ..failRemoveFromWishlist = true;
      final vm = ShoppingViewModel(fake);
      await vm.loadWishlist('user1');

      await vm.toggleWishlist('user1', 'w1');

      expect(vm.isWishlisted('w1'), true);
    });
  });
}
