import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';

class ProductListTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onAddToCart;

  const ProductListTile({
    super.key,
    required this.product,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: WunzaColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 100, // Larger image
            height: 100, // Larger image
            decoration: BoxDecoration(
              color: WunzaColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CachedNetworkImage(
              imageUrl: product.imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          const SizedBox(width: 16),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16, // Larger title
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Staples',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: WunzaColors.textSecondary,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.circle, size: 4, color: WunzaColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'In stock',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18, // Larger price
                              ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'USD',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: WunzaColors.primary,
                                fontSize: 12, // Larger tag
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: onAddToCart,
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 24, // Larger icon
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
