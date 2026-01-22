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

  Product({
    required this.productId,
    required this.name,
    required this.price,
    this.description = '',
    this.stock = 0,
    this.category = '',
    this.imageUrl = '',
    DateTime? createdAt,
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
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['product_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      stock: json['stock'] ?? 0,
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

