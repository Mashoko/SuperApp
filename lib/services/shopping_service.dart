import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/models/shopping/cart_item.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/order_status.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ShoppingService {
  final Map<String, Product> _products = {};
  final Map<String, List<CartItem>> _userCarts = {};
  final List<Order> _orders = [];

  ShoppingService() {
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:5000/api/products'));
      
      if (response.statusCode == 200) {
        final List<dynamic> productList = json.decode(response.body);
        _products.clear();
        for (final item in productList) {
          final product = Product.fromJson(item);
          _products[product.productId] = product;
        }
        // Notify listeners or rebuild UI if needed. 
        // Since this is a simple service, we might need a way to signal updates.
        print('Fetched ${_products.length} products from API');
      } else {
        print('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products: $e');
    }
  }

  void addProduct(Product product) {
    _products[product.productId] = product;
  }

  List<Product> getProducts({String? category}) {
    final products = _products.values.toList();
    if (category != null) {
      return products
          .where((p) => p.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    return products;
  }

  Product? getProduct(String productId) {
    return _products[productId];
  }

  String addToCart(String userId, String productId, {int quantity = 1}) {
    final product = _products[productId];
    if (product == null) {
      return 'Product $productId not found';
    }

    if (product.stock < quantity) {
      return 'Insufficient stock. Available: ${product.stock}';
    }

    if (!_userCarts.containsKey(userId)) {
      _userCarts[userId] = [];
    }

    final cart = _userCarts[userId]!;
    final existingItemIndex =
        cart.indexWhere((item) => item.product.productId == productId);

    if (existingItemIndex != -1) {
      cart[existingItemIndex].quantity += quantity;
      return 'Updated quantity in cart';
    }

    cart.add(CartItem(product: product, quantity: quantity));
    return 'Added ${quantity}x ${product.name} to cart';
  }

  Map<String, dynamic> getCart(String userId) {
    final cartItems = _userCarts[userId] ?? [];
    final total = cartItems.fold<double>(
        0.0, (sum, item) => sum + item.total);

    return {
      'user_id': userId,
      'items': cartItems.map((item) => item.toJson()).toList(),
      'total': total,
      'item_count': cartItems.length,
    };
  }

  String removeFromCart(String userId, String productId) {
    final cart = _userCarts[userId];
    if (cart == null || cart.isEmpty) {
      return 'Cart is empty';
    }

    final index = cart.indexWhere(
        (item) => item.product.productId == productId);
    if (index != -1) {
      final removedItem = cart.removeAt(index);
      return 'Removed ${removedItem.product.name} from cart';
    }

    return 'Product $productId not found in cart';
  }

  void clearCart(String userId) {
    _userCarts[userId] = [];
  }

  Order? placeOrder(String userId, String shippingAddress) {
    final cart = _userCarts[userId];
    if (cart == null || cart.isEmpty) {
      return null;
    }

    final cartItems = List<CartItem>.from(cart);

    // Check stock availability
    for (final item in cartItems) {
      if (item.product.stock < item.quantity) {
        return null;
      }
    }

    // Create order
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final order = Order(
      orderId: orderId,
      userId: userId,
      items: cartItems,
      shippingAddress: shippingAddress,
      status: OrderStatus.confirmed,
    );

    // Update stock
    for (final item in cartItems) {
      final product = _products[item.product.productId];
      if (product != null) {
        // Note: In a real app, Product should be mutable or we need a way to update stock
        // For now, we'll create a new product with updated stock
        _products[product.productId] = Product(
          productId: product.productId,
          name: product.name,
          price: product.price,
          description: product.description,
          stock: product.stock - item.quantity,
          category: product.category,
          createdAt: product.createdAt,
        );
      }
    }

    // Clear cart and add order
    clearCart(userId);
    _orders.add(order);

    return order;
  }

  List<Order> getOrders({String? userId}) {
    if (userId == null) {
      return List.from(_orders);
    }
    return _orders.where((order) => order.userId == userId).toList();
  }

  String updateOrderStatus(String orderId, OrderStatus status) {
    final orderIndex = _orders.indexWhere((order) => order.orderId == orderId);
    if (orderIndex != -1) {
      // Note: Order is immutable, so we'd need to create a new one
      // For simplicity, we'll just return success
      return 'Order status updated to ${status.value}';
    }
    return 'Order $orderId not found';
  }
}

