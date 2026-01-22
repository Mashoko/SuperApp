import 'package:flutter/material.dart';

class ShoppingSearchBar extends StatelessWidget {
  final VoidCallback? onCartPressed;
  final VoidCallback? onBackPressed;
  
  const ShoppingSearchBar({
    super.key, 
    this.onCartPressed,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Back Button
          if (onBackPressed != null)
             IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: onBackPressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (onBackPressed != null) const SizedBox(width: 12),

          // Search Field
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search product',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),

          // Filter Button
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.grey),
              onPressed: () {},
            ),
          ),

          // Cart Button (Optional/New)
          if (onCartPressed != null) ...[
             const SizedBox(width: 12),
             IconButton(
              onPressed: onCartPressed,
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
          ]
        ],
      ),
    );
  }
}
