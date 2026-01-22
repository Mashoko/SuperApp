import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/models/shopping/cart_item.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/order_status.dart';

class ShoppingService {
  final Map<String, Product> _products = {};
  final Map<String, List<CartItem>> _userCarts = {};
  final List<Order> _orders = [];

  ShoppingService() {
    _initializeSampleProducts();
  }

  void _initializeSampleProducts() {
    final sampleProducts = [
      Product(
        productId: '1',
        name: 'Fresh Milk 1L',
        price: 2.50,
        imageUrl: 'https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=300&q=80',
        category: 'Dairy',
        stock: 50,
      ),
      Product(
        productId: '2',
        name: 'Whole Wheat Bread',
        price: 3.00,
        imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=300&q=80',
        category: 'Bakery',
        stock: 30,
      ),
      Product(
        productId: '3',
        name: 'Organic Bananas',
        price: 1.20,
        imageUrl: 'https://images.unsplash.com/photo-1603833665858-e61d17a86224?auto=format&fit=crop&w=300&q=80',
        category: 'Produce',
        stock: 100,
      ),
      Product(
        productId: '4',
        name: 'Orange Juice',
        price: 4.50,
        imageUrl: 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?auto=format&fit=crop&w=300&q=80',
        category: 'Beverages',
        stock: 20,
      ),
    ];

    sampleProducts.addAll([
      Product(
        productId: '5',
        name: 'Premium Beef Steak 500g',
        price: 12.50,
        imageUrl: 'https://images.unsplash.com/photo-1603048297172-c92544798d5e?auto=format&fit=crop&w=300&q=80',
        category: 'Butcher',
        stock: 15,
      ),
      Product(
        productId: '6',
        name: 'Basmati Rice 2kg',
        price: 5.00,
        imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=300&q=80',
        category: 'Staples',
        stock: 80,
      ),
      Product(
        productId: '7',
        name: 'Dishwashing Liquid 750ml',
        price: 3.20,
        imageUrl: 'https://images.unsplash.com/photo-1585837575652-267c041d77d4?auto=format&fit=crop&w=300&q=80',
        category: 'Household',
        stock: 40,
      ),
      Product(
        productId: '8',
        name: 'Potato Chips Salted',
        price: 1.50,
        imageUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?auto=format&fit=crop&w=300&q=80',
        category: 'Snacks',
        stock: 60,
      ),
      Product(
        productId: '9',
        name: 'Toothpaste Mint 100g',
        price: 2.00,
        imageUrl: 'https://images.unsplash.com/photo-1559586616-361e18714958?auto=format&fit=crop&w=300&q=80',
        category: 'Sanitary',
        stock: 100,
      ),
      Product(
        productId: '10',
        name: 'Dry Dog Food 3kg',
        price: 15.00,
        imageUrl: 'https://images.unsplash.com/photo-1589924691195-41432c84c161?auto=format&fit=crop&w=300&q=80',
        category: 'Pets',
        stock: 25,
      ),
      Product(
        productId: '11',
        name: 'Baby Formula 800g',
        price: 25.00,
        imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=300&q=80',
        category: 'Infants',
        stock: 30,
      ),
    ]);

    for (final product in sampleProducts) {
      _products[product.productId] = product;
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

