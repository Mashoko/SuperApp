import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_card.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/shared/widgets/shimmer_widget.dart';

/// A titled, horizontally-scrolling row of real [Product] cards, with real
/// loading (shimmer)/success/empty/error states -- the real-data counterpart
/// to the static [DiscoverySection] used by Explore's other, still-placeholder
/// rows (Businesses, Deals).
class ExploreProductSection extends StatelessWidget {
  const ExploreProductSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyActionLabel,
    required this.onEmptyAction,
    required this.currentUserId,
    required this.isWishlisted,
    required this.onFavoriteTap,
    required this.onProductTap,
    required this.onAddToCart,
  });

  final String title;
  final String subtitle;
  final List<Product> products;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyActionLabel;
  final VoidCallback onEmptyAction;
  final String currentUserId;
  final bool Function(String productId) isWishlisted;
  final ValueChanged<Product> onFavoriteTap;
  final ValueChanged<Product> onProductTap;
  final ValueChanged<Product> onAddToCart;

  static const double _rowHeight = 240;
  static const double _cardWidth = 200;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        key: const Key('explore-product-section-shimmer'),
        height: _rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => SizedBox(
            width: _cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(child: ShimmerWidget.rectangular(height: double.infinity)),
                SizedBox(height: 8),
                ShimmerWidget.rectangular(height: 14),
                SizedBox(height: 6),
                ShimmerWidget.rectangular(height: 14, width: 80),
              ],
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(emptyTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(emptyMessage, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(onPressed: onEmptyAction, child: Text(emptyActionLabel)),
          ],
        ),
      );
    }

    return SizedBox(
      height: _rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final product = products[i];
          return SizedBox(
            width: _cardWidth,
            child: ProductCard(
              product: product,
              isFavorited: isWishlisted(product.productId),
              onTap: () => onProductTap(product),
              onAddToCart: () => onAddToCart(product),
              onFavorite: () => onFavoriteTap(product),
            ),
          );
        },
      ),
    );
  }
}
