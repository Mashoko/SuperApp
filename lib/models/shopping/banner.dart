class Banner {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final bool isActive;

  Banner({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.isActive,
  });

  factory Banner.fromJson(Map<String, dynamic> json) {
    return Banner(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }
}
