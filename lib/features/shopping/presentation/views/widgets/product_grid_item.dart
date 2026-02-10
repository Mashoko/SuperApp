import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/quantity_selector.dart';

class ProductGridItem extends StatelessWidget {
  final Product product;

  const ProductGridItem({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WunzaColors.premiumSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: WunzaColors.premiumGrey,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Center(
                   child: Icon(Icons.image, color: Colors.grey[300]),
                ),
                errorWidget: (context, url, error) => Center(
                   child: Icon(Icons.image_not_supported, color: Colors.grey[300]),
                ),
              ),
            ),
          ),
          
          // Details Area
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: WunzaColors.premiumText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'per ${product.unit}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WunzaColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: WunzaColors.premiumText,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                    ),
                    Consumer<ShoppingViewModel>(
                      builder: (context, viewModel, child) {
                        final quantity = viewModel.getProductQuantity(product.productId);
                        return QuantitySelector(
                          quantity: quantity,
                          onAdd: () => viewModel.addToCart('user_id', product.productId),
                          onIncrement: () => viewModel.updateCartQuantity('user_id', product.productId, quantity + 1),
                          onRemove: () => viewModel.updateCartQuantity('user_id', product.productId, quantity - 1),
                        );
                      },
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
