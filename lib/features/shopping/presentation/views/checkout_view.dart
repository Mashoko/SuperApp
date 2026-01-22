import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/shared/widgets/payment_method_sheet.dart';


class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
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
          final List<dynamic> cartItems = viewModel.cart['items'] ?? [];
          final double subtotal = viewModel.cart['total'] ?? 0.0;
          const double shipping = 0.0; // Mock shipping
          final double total = subtotal + shipping;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Items List
                ...cartItems.map((item) {
                  final productData = item['product'];
                  final product = Product.fromJson(productData);
                  final quantity = item['quantity'] as int;
                  
                  return _buildCheckoutItem(
                    name: product.name,
                    price: product.price,
                    quantity: quantity,
                    imageUrl: product.imageUrl,
                    onDelete: () => _confirmDelete(() => viewModel.removeFromCart('user_id', product.productId)),
                    onIncrement: () => viewModel.addToCart('user_id', product.productId),
                    onDecrement: () {
                      if (quantity > 1) {
                         viewModel.addToCart('user_id', product.productId, quantity: -1);
                      } else {
                        viewModel.removeFromCart('user_id', product.productId);
                      }
                    },
                  );
                }),
                
                const SizedBox(height: 24),
                
                const Text(
                  'Payment Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Promo Code
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF0E6), // Light orange
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.percent, color: WunzaColors.primary, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enter your promo code',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Use your promo code or voucher',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Summary
                _buildSummaryRow('Subtotal', subtotal),
                _buildSummaryRow('Shipping', shipping),
                const Divider(height: 32),
                _buildSummaryRow('Total', total, isTotal: true),
                
                const SizedBox(height: 32),
                
                // Checkout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => PaymentMethodSheet.show(
                      context, 
                      onSuccess: () {
                        // After success dialog, maybe navigate home or order history
                        Navigator.pop(context); // Close checkout
                      }
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WunzaColors.primary, // Orange
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Pay with Paynow',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckoutItem({
    required String name,
    required double price,
    required int quantity,
    required String imageUrl,
    required VoidCallback onDelete,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (c, o, s) => Container(color: Colors.grey[200], width: 80, height: 80),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Icon(Icons.more_horiz, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Staples', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.circle, size: 4, color: Colors.grey),
                    const SizedBox(width: 4),
                    const Text('In stock', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: onDecrement,
                            child: _buildQtyBtn(Icons.remove),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          GestureDetector(
                            onTap: onIncrement,
                            child: _buildQtyBtn(Icons.add),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'USD',
                      style: TextStyle(color: WunzaColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline, color: Colors.red),
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

  Widget _buildQtyBtn(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      child: Icon(icon, size: 16),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.bold,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? Colors.black : Colors.black,
            ),
          ),
        ],
      ),
    );
  }



  void _confirmDelete(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: const Text('Are you sure you want to remove this item from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
