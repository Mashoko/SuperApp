import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/category_sidebar.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/checkout_bar.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_list_tile.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/shopping_search_bar.dart';

class CategoryProductView extends StatefulWidget {
  const CategoryProductView({super.key});

  @override
  State<CategoryProductView> createState() => _CategoryProductViewState();
}

class _CategoryProductViewState extends State<CategoryProductView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final viewModel = Provider.of<ShoppingViewModel>(context, listen: false);
      viewModel.loadMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ShoppingSearchBar(
              onBackPressed: () { Future.delayed(Duration.zero, () { if (context.mounted) Navigator.pop(context); }); },
              onCartPressed: () => Navigator.pushNamed(context, Routes.cart),
            ),
            Expanded(
              child: Consumer<ShoppingViewModel>(
                builder: (context, viewModel, child) {
                  return Row(
                    children: [
                      CategorySidebar(
                        categories: viewModel.categories,
                        selectedCategory: viewModel.selectedCategory,
                        onCategorySelected: (category) {
                          viewModel.selectCategory(category);
                          // Reset scroll position when category changes
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(0);
                          }
                        },
                      ),
                      Expanded(
                        child: viewModel.isLoading && viewModel.products.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: viewModel.products.length + (viewModel.isMoreLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == viewModel.products.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
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
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Consumer<ShoppingViewModel>(
              builder: (context, viewModel, child) {
                // Calculate total items and amount from cart
                // For now, using dummy values or implementing simple logic if cart structure allows
                int itemCount = 0;
                double totalAmount = 0.0;
                
                // In a real app, iterate through cart items
                // itemCount = viewModel.cart.length;
                
                return CheckoutBar(
                  itemCount: itemCount,
                  totalAmount: totalAmount,
                  onCheckout: () => Navigator.pushNamed(context, Routes.cart),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
