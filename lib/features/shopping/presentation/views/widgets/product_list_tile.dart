import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/quantity_selector.dart';

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
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          // Product Image
          Container(
            width: 80, 
            height: 80, 
            decoration: BoxDecoration(
              color: WunzaColors.premiumGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: CachedNetworkImage(
              imageUrl: product.imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => Center(
                 child: Icon(Icons.image, color: Colors.grey[300]),
              ),
              errorWidget: (context, url, error) => Center(
                 child: Icon(Icons.broken_image, color: Colors.grey[300]),
              ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: WunzaColors.premiumText,
                      ),
                ),
                const SizedBox(height: 4),
                // Unit of measure
                Text(
                  'per ${product.unit}', 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WunzaColors.textSecondary,
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: WunzaColors.premiumText,
                            fontWeight: FontWeight.bold,
                            fontSize: 18, 
                          ),
                    ),
                    Consumer<ShoppingViewModel>(
                      builder: (context, viewModel, child) {
                        final quantity = viewModel.getProductQuantity(product.productId);
                        return QuantitySelector(
                          quantity: quantity,
                          onAdd: () {
                            if (onAddToCart != null) {
                              onAddToCart!();
                            } else {
                              viewModel.addToCart('user_id', product.productId);
                            }
                          },
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
