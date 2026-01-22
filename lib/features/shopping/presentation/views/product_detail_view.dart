import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_grid.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/quantity_selector.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/section_header.dart';

class ProductDetailView extends StatefulWidget {
  const ProductDetailView({super.key});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = ModalRoute.of(context)!.settings.arguments as Product;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              // Toggle favorite
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.pushNamed(context, Routes.cart),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
            Container(
              height: 400, // Increased height
              width: double.infinity,
              color: Colors.white,
              child: Hero(
                tag: 'product_${product.productId}',
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            
            Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24.0), // Increased padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 26, // Larger title
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 24, // Larger price
                            ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'USD',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: WunzaColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                        // Quantity
                        Row(
                          children: [
                            Text(
                              'Quantity',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 16),
                            QuantitySelector(
                              quantity: _quantity,
                              onIncrement: () {
                                setState(() {
                                  _quantity++;
                                });
                              },
                              onDecrement: () {
                                if (_quantity > 1) {
                                  setState(() {
                                    _quantity--;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Product Details',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description.isNotEmpty
                              ? product.description
                              : 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: WunzaColors.textSecondary,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 24),

                        // Related Products
                        const SectionHeader(title: 'Related Products'),
                        Consumer<ShoppingViewModel>(
                          builder: (context, viewModel, child) {
                            // Filter related products (excluding current)
                            final relatedProducts = viewModel.products
                                .where((p) => p.productId != product.productId)
                                .take(2)
                                .toList();
                            
                            return ProductGrid(
                              products: relatedProducts,
                              onProductTap: (p) {
                                Navigator.pushReplacementNamed(
                                  context,
                                  Routes.productDetails,
                                  arguments: p,
                                );
                              },
                              onAddToCart: (p) {
                                viewModel.addToCart('user_id', p.productId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${p.name} added to cart')),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Action Bar
          Container(
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Provider.of<ShoppingViewModel>(context, listen: false)
                            .addToCart('user_id', product.productId, quantity: _quantity);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${product.name} added to cart')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WunzaColors.primary, // Orange
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Add Cart'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Add to cart and go to checkout
                        Provider.of<ShoppingViewModel>(context, listen: false)
                            .addToCart('user_id', product.productId, quantity: _quantity);
                        Navigator.pushNamed(context, Routes.cart);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WunzaColors.secondary, // Black/Dark Grey
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Checkout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
