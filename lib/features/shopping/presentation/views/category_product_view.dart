import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/category_sidebar.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/checkout_bar.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_list_tile.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/shopping_search_bar.dart';

class CategoryProductView extends StatelessWidget {
  const CategoryProductView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ShoppingSearchBar(
              onBackPressed: () => Navigator.pop(context),
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
                      },
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
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
