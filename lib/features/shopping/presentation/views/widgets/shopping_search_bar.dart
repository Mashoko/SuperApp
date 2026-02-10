import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class ShoppingSearchBar extends StatelessWidget {
  final VoidCallback? onCartPressed;
  final VoidCallback? onBackPressed;
  final int cartItemCount;

  const ShoppingSearchBar({
    super.key, 
    this.onCartPressed,
    this.onBackPressed,
    this.cartItemCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Back Button
          if (onBackPressed != null)
             IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: onBackPressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: WunzaColors.premiumText,
            ),
          if (onBackPressed != null) const SizedBox(width: 12),

          // Search Field
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: WunzaColors.premiumSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search product',
                  hintStyle: TextStyle(color: WunzaColors.textSecondary),
                  prefixIcon: Icon(Icons.search, color: WunzaColors.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
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
              color: WunzaColors.premiumSurface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: WunzaColors.premiumText),
              onPressed: () {},
            ),
          ),

          // Cart Button
          if (onCartPressed != null) ...[
             const SizedBox(width: 12),
             Stack(
               children: [
                 IconButton(
                   onPressed: onCartPressed,
                   icon: const Icon(Icons.shopping_cart_outlined, color: WunzaColors.premiumText),
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
