import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/shared/widgets/glass_container.dart';

class ShoppingSearchBar extends StatelessWidget {
  final VoidCallback? onCartPressed;
  final VoidCallback? onBackPressed;
  
  const ShoppingSearchBar({
    super.key, 
    this.onCartPressed,
    this.onBackPressed,
    this.cartItemCount = 0,
  });

  final int cartItemCount;

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
            child: SizedBox(
              height: 48,
              child: GlassContainer(
                opacity: 0.5,
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
          ),
          
          const SizedBox(width: 12),

          // Filter Button
          SizedBox(
            height: 48,
            width: 48,
            child: GlassContainer(
              opacity: 0.5,
              borderRadius: 12,
              child: IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.grey),
              onPressed: () {},
            ),
            ),
          ),

          // Cart Button (Optional/New)
          if (onCartPressed != null) ...[
             const SizedBox(width: 12),
             Stack(
               children: [
                 IconButton(
                   onPressed: onCartPressed,
                   icon: const Icon(Icons.shopping_cart_outlined),
                 ),
                 if (cartItemCount > 0)
                   Positioned(
                     right: 8,
                     top: 8,
                     child: Container(
                       padding: const EdgeInsets.all(4),
                       decoration: const BoxDecoration(
                         color: Colors.red,
                         shape: BoxShape.circle,
                       ),
                       constraints: const BoxConstraints(
                         minWidth: 16,
                         minHeight: 16,
                       ),
                       child: Text(
                         '$cartItemCount',
                         style: const TextStyle(
                           color: Colors.white,
                           fontSize: 10,
                           fontWeight: FontWeight.bold,
                         ),
                         textAlign: TextAlign.center,
                       ),
                     ),
                   ),
               ],
             ),
          ]
        ],
      ),
    );
  }
}
