import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;
  final Function(Product) onAddToCart;
  final ProductViewMode viewMode;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    required this.onAddToCart,
    this.viewMode = ProductViewMode.medium,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: viewMode == ProductViewMode.large
            ? 1
            : viewMode == ProductViewMode.medium
                ? 2
                : viewMode == ProductViewMode.small
                    ? 4 // 4 columns for small mode
                    : 6, // 6 columns for extra small mode
        childAspectRatio: viewMode == ProductViewMode.large
            ? 1.1
            : viewMode == ProductViewMode.medium
                ? 0.75
                : 0.7, // Compact aspect ratio for small/XS
        crossAxisSpacing: (viewMode == ProductViewMode.small || viewMode == ProductViewMode.extraSmall) ? 8 : 16,
        mainAxisSpacing: (viewMode == ProductViewMode.small || viewMode == ProductViewMode.extraSmall) ? 8 : 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          viewMode: viewMode, // Pass viewMode
          onTap: () => onProductTap(product),
          onAddToCart: () => onAddToCart(product),
          onFavorite: () {
            // TODO: Implement favorite
          },
        );
      },
    );
  }
}
