import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final bool isFavorited;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onFavorite;
  final ProductViewMode viewMode;

  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorited,
    this.onTap,
    this.onAddToCart,
    this.onFavorite,
    this.viewMode = ProductViewMode.medium,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = viewMode == ProductViewMode.small || viewMode == ProductViewMode.extraSmall;
    final hasDiscount = product.discountPrice != null && product.discountPrice! < product.price;
    final discountPercent = hasDiscount
        ? (((product.price - product.discountPrice!) / product.price) * 100).round()
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: WunzaColors.surface,
          borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: isSmall ? 4 : 8,
              offset: Offset(0, isSmall ? 1 : 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(isSmall ? 8 : 12)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl.isNotEmpty
                          ? product.imageUrl
                          : 'https://via.placeholder.com/150',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error, size: 16),
                      ),
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: WunzaColors.padGradientEnd,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (!isSmall) // Hide favorite in small mode to save space
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorited ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFavorited ? WunzaColors.padGradientEnd : WunzaColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info Section
            Padding(
              padding: EdgeInsets.all(isSmall ? 4.0 : 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isSmall)
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  if (!isSmall &&
                      ((product.storeName != null && product.storeName!.isNotEmpty) ||
                          product.verifiedSeller)) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (product.storeName != null && product.storeName!.isNotEmpty)
                          Flexible(
                            child: Text(
                              product.storeName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: WunzaColors.textSecondary,
                                  ),
                            ),
                          ),
                        if (product.verifiedSeller) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: WunzaColors.primary),
                        ],
                      ],
                    ),
                  ],
                  if (!isSmall && product.reviewCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${product.averageRating.toStringAsFixed(1)} (${product.reviewCount})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: WunzaColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ],
                  if (!isSmall && product.deliveryAvailable) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 14, color: WunzaColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Delivery',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: WunzaColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ],
                  if (!isSmall) const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '\$${(hasDiscount ? product.discountPrice! : product.price).toStringAsFixed(isSmall ? 0 : 2)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSmall ? 12 : 18,
                                      ),
                                ),
                                if (!isSmall) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    'USD',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: WunzaColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                            if (!isSmall && hasDiscount) ...[
                              const SizedBox(width: 6),
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: WunzaColors.textSecondary,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onAddToCart,
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 24,
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
      ),
    );
  }
}
