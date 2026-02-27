import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/cart_item_tile.dart';

class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart (2)'), // Mock count for now
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () { Future.delayed(Duration.zero, () { if (context.mounted) Navigator.pop(context); }); },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<ShoppingViewModel>(
        builder: (context, viewModel, child) {
          // TODO: Replace with actual cart items from ViewModel
          // For now, mocking empty state if cart is empty
          final List<dynamic> cartItems = viewModel.cart['items'] ?? [];

          if (cartItems.isEmpty) {
            return _buildEmptyCart(context);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final productData = item['product'];
                    // We can use the product data directly from the cart item
                    // or look it up. Since we have it, let's use it to be safe.
                    // But we need a Product object.
                    final product = Product.fromJson(productData);
                    final quantity = item['quantity'] as int;
                    
                    return CartItemTile(
                      product: product,
                      quantity: quantity,
                      onIncrement: () => viewModel.addToCart('user_id', product.productId),
                      onDecrement: () {
                        if (quantity > 1) {
                          // For now, we don't have a direct updateQuantity, so we add -1? 
                          // Or we need to implement updateQuantity in ViewModel/Service.
                          // Service has addToCart which adds. 
                          // Service doesn't have explicit decrement, but addToCart adds to existing.
                          // Wait, addToCart adds. To decrement we need a different method or pass negative?
                          // Service: cart[existingItemIndex].quantity += quantity;
                          // So passing -1 should work!
                          viewModel.addToCart('user_id', product.productId, quantity: -1);
                        } else {
                          viewModel.removeFromCart('user_id', product.productId);
                        }
                      },
                      onDelete: () => viewModel.removeFromCart('user_id', product.productId),
                    );
                  },
                ),
              ),
              _buildBottomBar(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
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
                Icons.shopping_cart_outlined,
                size: 64,
                color: WunzaColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your Cart is Empty',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Looks like you haven\'t added anything to your cart yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: WunzaColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Future.delayed(Duration.zero, () { if (context.mounted) Navigator.pop(context); }); },
                child: const Text('Start Shopping'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ShoppingViewModel viewModel) {
    // Calculate total (mock)
    double total = 0.0;
    // viewModel.cart.forEach((key, value) { ... });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WunzaColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: WunzaColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, Routes.checkout);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WunzaColors.primary, // Orange
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
