import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/category_sidebar.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/checkout_bar.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_list_tile.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/shopping_search_bar.dart';

class ShoppingView extends StatefulWidget {
  const ShoppingView({super.key});

  @override
  State<ShoppingView> createState() => _ShoppingViewState();
}

class _ShoppingViewState extends State<ShoppingView> {
  @override
  void initState() {
    super.initState();
    // Load products if needed, or rely on dummy data for now
    // Load products if needed, or rely on dummy data for now
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ShoppingViewModel>(context, listen: false).loadProducts();
    });
  }


  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Popular': return Icons.trending_up;
      case 'Produce': return Icons.local_grocery_store;
      case 'Butcher': return Icons.kebab_dining;
      case 'Bakery': return Icons.bakery_dining;
      case 'Staples': return Icons.rice_bowl;
      case 'Dairy': return Icons.local_pizza;
      case 'Infants': return Icons.child_care;
      case 'Beverages': return Icons.local_drink;
      case 'Household': return Icons.cleaning_services;
      case 'Snacks': return Icons.fastfood;
      case 'Sanitary': return Icons.soap;
      case 'Pets': return Icons.pets;
      default: return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Sidebar
                Consumer<ShoppingViewModel>(
                  builder: (context, viewModel, child) {
                    return CategorySidebar(
                      categories: viewModel.categories,
                      selectedCategory: viewModel.selectedCategory,
                      onCategorySelected: (category) {
                        viewModel.selectCategory(category);
                      },
                    );
                  },
                ),
                
                // Main Content
                Expanded(
                  child: Column(
                    children: [
                      // Top Bar
                      ShoppingSearchBar(
                        onBackPressed: () => Navigator.pop(context),
                        onCartPressed: () => Navigator.pushNamed(context, Routes.cart),
                      ),
                      
                      // Category Header
                      Consumer<ShoppingViewModel>(
                        builder: (context, viewModel, child) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(viewModel.selectedCategory),
                                  color: WunzaColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  viewModel.selectedCategory,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Product List
                      Expanded(
                        child: Consumer<ShoppingViewModel>(
                          builder: (context, viewModel, child) {
                            if (viewModel.isLoading) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Bottom padding for checkout bar
                              itemCount: viewModel.products.length,
                              itemBuilder: (context, index) {
                                final product = viewModel.products[index];
                                return ProductListTile(
                                  product: product,
                                  onAddToCart: () {
                                    viewModel.addToCart('user_id', product.productId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${product.name} added to cart')),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Checkout Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Consumer<ShoppingViewModel>(
                builder: (context, viewModel, child) {
                  final itemCount = viewModel.cart['item_count'] as int? ?? 0;
                  final totalAmount = viewModel.cart['total'] as double? ?? 0.0;
                  
                  return CheckoutBar(
                    itemCount: itemCount,
                    totalAmount: totalAmount,
                    onCheckout: () {
                       Navigator.pushNamed(context, Routes.checkout);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
