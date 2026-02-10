import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/checkout_bar.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_list_tile.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_grid_item.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/shopping_search_bar.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/category_pills.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/promotional_banner.dart';

class ShoppingView extends StatefulWidget {
  const ShoppingView({super.key});

  @override
  State<ShoppingView> createState() => _ShoppingViewState();
}

class _ShoppingViewState extends State<ShoppingView> {
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ShoppingViewModel>(context, listen: false).loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WunzaColors.premiumGrey,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top Bar
                Consumer<ShoppingViewModel>(
                  builder: (context, viewModel, child) {
                    final itemCount = viewModel.cart['item_count'] as int? ?? 0;
                    return ShoppingSearchBar(
                      onBackPressed: () => Navigator.pop(context),
                      onCartPressed: () => Navigator.pushNamed(context, Routes.cart),
                      cartItemCount: itemCount,
                    );
                  },
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         // Promotional Banner
                        Consumer<ShoppingViewModel>(
                          builder: (context, viewModel, child) {
                            return PromotionalBanner(
                              banner: viewModel.banners.isNotEmpty ? viewModel.banners.first : null,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Categories (Pills)
                         Consumer<ShoppingViewModel>(
                          builder: (context, viewModel, child) {
                            return CategoryPills(
                              categories: viewModel.categories,
                              selectedCategory: viewModel.selectedCategory,
                              onCategorySelected: (category) {
                                viewModel.selectCategory(category);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Section Header + Toggle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Popular Products",
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: WunzaColors.premiumText,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isGridView ? Icons.view_list : Icons.grid_view,
                                  color: WunzaColors.premiumText,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isGridView = !_isGridView;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Product List/Grid
                        Consumer<ShoppingViewModel>(
                          builder: (context, viewModel, child) {
                            if (viewModel.isLoading) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            // Bottom padding for checkout bar
                            final bottomPadding = const EdgeInsets.only(bottom: 100, left: 16, right: 16);

                            if (_isGridView) {
                               return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: bottomPadding,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: viewModel.products.length,
                                itemBuilder: (context, index) {
                                  final product = viewModel.products[index];
                                  return ProductGridItem(
                                    product: product,
                                  );
                                },
                              );
                            } else {
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: bottomPadding.copyWith(left: 0, right: 0),
                                itemCount: viewModel.products.length,
                                itemBuilder: (context, index) {
                                  final product = viewModel.products[index];
                                  return ProductListTile(
                                    product: product,
                                  );
                                },
                              );
                            }
                          },
                        ),
                      ],
                    ),
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
                  
                  return SafeArea(
                    child: CheckoutBar(
                      itemCount: itemCount,
                      totalAmount: totalAmount,
                      onCheckout: () {
                         Navigator.pushNamed(context, Routes.checkout);
                      },
                    ),
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

