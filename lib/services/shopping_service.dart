import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/banner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ShoppingService {
  ShoppingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base = 'https://superapp-diht.onrender.com/api';

  // ── Product catalog (in-memory cache for browse) ──────────────────────────
  final Map<String, Product> _products = {};

  Future<({List<Product> products, int totalPages, bool ok})> fetchProducts({
    int page = 1,
    int limit = 10,
    String? category,
    String? search,
  }) async {
    try {
      final params = <String, String>{
        'page': '$page',
        'limit': '$limit',
      };
      if (category != null && category != 'All') params['category'] = category;
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

      final uri = Uri.parse('$_base/products').replace(queryParameters: params);
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        List<dynamic> productList;
        int totalPages = 1;

        if (decoded is List) {
          productList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          productList = decoded['products'] ?? [];
          totalPages = decoded['totalPages'] ?? 1;
        } else {
          return (products: <Product>[], totalPages: 0, ok: false);
        }

        final List<Product> newProducts = [];
        for (final item in productList) {
          final product = Product.fromJson(item);
          _products[product.productId] = product;
          newProducts.add(product);
        }
        return (products: newProducts, totalPages: totalPages, ok: true);
      } else {
        return (products: <Product>[], totalPages: 0, ok: false);
      }
    } catch (e) {
      return (products: <Product>[], totalPages: 0, ok: false);
    }
  }

  Future<({List<Product> products, int totalPages, bool ok})> fetchTrendingProducts({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse('$_base/products').replace(queryParameters: {
        'sort': 'trending',
        'page': '$page',
        'limit': '$limit',
      });
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final productList = decoded['products'] as List<dynamic>? ?? [];
        final totalPages = decoded['totalPages'] as int? ?? 1;
        return (
          products: productList.map((item) => Product.fromJson(item)).toList(),
          totalPages: totalPages,
          ok: true,
        );
      }
      return (products: <Product>[], totalPages: 0, ok: false);
    } catch (e) {
      return (products: <Product>[], totalPages: 0, ok: false);
    }
  }

  Future<({List<Product> products, int totalPages, bool ok})> fetchRecommendedProducts({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse('$_base/products').replace(queryParameters: {
        'sort': 'recommended',
        'userId': userId,
        'page': '$page',
        'limit': '$limit',
      });
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final productList = decoded['products'] as List<dynamic>? ?? [];
        final totalPages = decoded['totalPages'] as int? ?? 1;
        return (
          products: productList.map((item) => Product.fromJson(item)).toList(),
          totalPages: totalPages,
          ok: true,
        );
      }
      return (products: <Product>[], totalPages: 0, ok: false);
    } catch (e) {
      return (products: <Product>[], totalPages: 0, ok: false);
    }
  }

  Future<List<String>> fetchCategories() async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/categories?hasProducts=true'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => j['name'].toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Banner>> fetchBanners() async {
    try {
      final response = await _client.get(Uri.parse('$_base/banners'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Banner.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Product? getProduct(String productId) => _products[productId];

  // ── Cart (server-side) ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchCart(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/cart?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<Map<String, dynamic>> addToCart(String userId, String productId,
      {int quantity = 1}) async {
    try {
      final response = await _client.post(
        Uri.parse('$_base/cart/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<Map<String, dynamic>> updateCartQuantity(
      String userId, String productId, int quantity) async {
    if (quantity <= 0) return removeFromCart(userId, productId);
    try {
      final response = await _client.put(
        Uri.parse('$_base/cart/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<Map<String, dynamic>> removeFromCart(
      String userId, String productId) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$_base/cart/remove'));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'userId': userId, 'productId': productId});
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<void> clearCart(String userId) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$_base/cart/clear'));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'userId': userId});
      final streamedResponse = await _client.send(request);
      await http.Response.fromStream(streamedResponse);
    } catch (_) {}
  }

  Map<String, dynamic> _emptyCart(String userId) => {
        'user_id': userId,
        'items': <dynamic>[],
        'total': 0.0,
        'item_count': 0,
      };

  // ── Orders (server-side) ──────────────────────────────────────────────────

  Future<Order?> placeOrder(
    String userId,
    String shippingAddress, {
    String? transactionId,
    String paymentStatus = 'pending',
    double discountAmount = 0.0,
    String? discountCode,
    required Map<String, dynamic> cartSnapshot,
  }) async {
    try {
      final cartItems = cartSnapshot['items'] as List<dynamic>? ?? [];
      final total = (cartSnapshot['total'] as num?)?.toDouble() ?? 0.0;

      final itemsPayload = cartItems.map((item) {
        final productData = item['product'] as Map<String, dynamic>;
        final quantity = item['quantity'] as int;
        final itemTotal = (item['total'] as num?)?.toDouble() ?? 0.0;
        return {
          'product': productData,
          'quantity': quantity,
          'total': itemTotal,
        };
      }).toList();

      final response = await _client.post(
        Uri.parse('$_base/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'items': itemsPayload,
          'shippingAddress': shippingAddress,
          'transactionId': transactionId,
          'paymentStatus': paymentStatus,
          'total': total - discountAmount,
          'discountCode': discountCode,
          'discountAmount': discountAmount,
        }),
      );

      if (response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return Order.fromJson(decoded);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Order>> fetchOrders(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/orders?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Order.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Wishlist ──────────────────────────────────────────────────────────────

  Future<int> fetchWishlistCount(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/wishlist?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.length;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Product>> fetchWishlist(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/wishlist?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Product.fromJson(j)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> addToWishlist(String userId, String productId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_base/wishlist/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'productId': productId}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to add to wishlist');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> removeFromWishlist(String userId, String productId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_base/wishlist/remove/$productId')
            .replace(queryParameters: {'userId': userId}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to remove from wishlist');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Voucher ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> validateVoucher(
      String code, double total) async {
    try {
      final response = await _client.post(
        Uri.parse('$_base/validate-voucher'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': code, 'cart_total': total}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Invalid voucher');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
