import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/shared/widgets/glass_container.dart';

class CheckoutBar extends StatelessWidget {
  final int itemCount;
  final double totalAmount;
  final VoidCallback? onCheckout;

  const CheckoutBar({
    super.key,
    required this.itemCount,
    required this.totalAmount,
    this.onCheckout,
  });


  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: SizedBox(
          height: 80, // Taller bar
          child: GlassContainer(
             color: WunzaColors.primary.withValues(alpha: 0.9), // Keep it mostly opaque orange
             borderRadius: 40,
             blur: 10,

            child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cheetah Image (Left, overflowing)
              Positioned(
                left: 12,
                bottom: 0,
                child: SizedBox(
                  width: 70, // Larger cheetah
                  height: 95, // Taller to overflow more
                  child: CachedNetworkImage(
                    imageUrl: 'https://png.pngtree.com/png-clipart/20230414/original/pngtree-cheetah-animal-png-image_9056372.png',
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const SizedBox(),
                    errorWidget: (context, url, error) => const SizedBox(),
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.only(left: 90, right: 12), // Adjusted padding
                child: Row(
                  children: [
                    // Total Amount
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '\$${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22, // Larger amount
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'USD',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12, // Larger currency tag
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Cart Icon Circle
                    Container(
                      padding: const EdgeInsets.all(10), // Larger padding
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.black,
                        size: 24, // Larger icon
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Checkout Button
                    ElevatedButton(
                      onPressed: onCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), // Larger button
                      ),
                      child: const Text(
                        'Checkout',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
