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
      padding: const EdgeInsets.all(8),
      child: SafeArea(
        child: SizedBox(
          height: 80,
          child: GlassContainer(
            color: WunzaColors.primary.withValues(alpha: 0.9),
            borderRadius: 40,
            blur: 10,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 12,
                  bottom: 0,
                  child: SizedBox(
                    width: 70,
                    height: 95,
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://png.pngtree.com/png-clipart/20230414/original/pngtree-cheetah-animal-png-image_9056372.png',
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(),
                      errorWidget: (context, url, error) => const SizedBox(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 90, right: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Total Amount
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'USD',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      // Cart Icon Circle
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Checkout Button
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: onCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text(
                            'Checkout',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
