enum ProductViewMode { extraSmall, small, medium, large }

class Product {
  final String productId;
  final String name;
  final double price;
  final String description;
  final int stock;
  final String category;
  final String imageUrl;
  final DateTime createdAt;
  final String unit;
  final double? discountPrice;
  final double averageRating;
  final int reviewCount;
  final bool isTrending;
  final String? storeName;
  final bool verifiedSeller;
  final bool deliveryAvailable;

  Product({
    required this.productId,
    required this.name,
    required this.price,
    this.description = '',
    this.stock = 0,
    this.category = '',
    this.imageUrl = '',
    this.unit = 'kg',
    DateTime? createdAt,
    this.discountPrice,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.isTrending = false,
    this.storeName,
    this.verifiedSeller = false,
    this.deliveryAvailable = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'description': description,
      'stock': stock,
      'category': category,
      'image_url': imageUrl,
      'unit': unit,
      'created_at': createdAt.toIso8601String(),
      'discountPrice': discountPrice,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'isTrending': isTrending,
      'storeName': storeName,
      'verifiedSeller': verifiedSeller,
      'deliveryAvailable': deliveryAvailable,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['_id'] ?? json['product_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      stock: (json['stock'] != null && json['stock'] is int && json['stock'] > 0) ? json['stock'] : 100,
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      unit: json['unit'] ?? 'kg',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      discountPrice: (json['discountPrice'] as num?)?.toDouble(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      isTrending: json['isTrending'] as bool? ?? false,
      storeName: json['storeName'] as String?,
      verifiedSeller: json['verifiedSeller'] as bool? ?? false,
      deliveryAvailable: json['deliveryAvailable'] as bool? ?? false,
    );
  }
}
