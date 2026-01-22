import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/wishlist_tile.dart';

class WishlistView extends StatelessWidget {
  const WishlistView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<ShoppingViewModel>(
          builder: (context, viewModel, child) {
            // Mock wishlist count
            int count = 2; 
            return Text('Wishlist ($count)');
          },
        ),
      ),
      body: Consumer<ShoppingViewModel>(
        builder: (context, viewModel, child) {
          // Mock wishlist items
          // In real app, use viewModel.wishlist
          final wishlistItems = viewModel.products.take(2).toList();

          if (wishlistItems.isEmpty) {
            return _buildEmptyWishlist(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: wishlistItems.length,
            itemBuilder: (context, index) {
              final product = wishlistItems[index];
              return WishlistTile(
                product: product,
                onAddToCart: () {
                  viewModel.addToCart('user_id', product.productId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${product.name} added to cart')),
                  );
                },
                onDelete: () {
                  // Remove from wishlist
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyWishlist(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: WunzaColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 64,
                color: WunzaColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your Wishlist is Empty',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the heart icon to save items for later.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: WunzaColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, 
                  Routes.shopping, 
                  (route) => false
                ),
                child: const Text('Start Browsing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
