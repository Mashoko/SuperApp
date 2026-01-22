import 'package:mvvm_sip_demo/models/shopping/cart_item.dart';
import 'package:mvvm_sip_demo/models/shopping/order_status.dart';

class Order {
  final String orderId;
  final String userId;
  final List<CartItem> items;
  final String shippingAddress;
  final OrderStatus status;
  final DateTime createdAt;
  final double totalAmount;

  Order({
    required this.orderId,
    required this.userId,
    required this.items,
    required this.shippingAddress,
    this.status = OrderStatus.pending,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        totalAmount = items.fold(0.0, (sum, item) => sum + item.total);

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'user_id': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'shipping_address': shippingAddress,
      'status': status.value,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['order_id'] ?? '',
      userId: json['user_id'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => CartItem.fromJson(item))
              .toList() ??
          [],
      shippingAddress: json['shipping_address'] ?? '',
      status: OrderStatusExtension.fromString(json['status'] ?? 'pending'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

