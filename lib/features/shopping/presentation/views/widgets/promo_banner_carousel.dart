import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class PromoBannerCarousel extends StatelessWidget {
  final List<String> bannerImages;

  const PromoBannerCarousel({
    super.key,
    this.bannerImages = const [
      'https://picsum.photos/seed/promo1/800/400',
      'https://picsum.photos/seed/promo2/800/400',
      'https://picsum.photos/seed/promo3/800/400',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Container(
        width: double.infinity,
        height: 180, // Increased height
        decoration: BoxDecoration(
          color: WunzaColors.primary,
          borderRadius: BorderRadius.circular(20), // More rounded
        ),
        child: Stack(
          children: [
            // Text Content
            Padding(
              padding: const EdgeInsets.all(24.0), // More padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Fresh produce and\ngroceries all available',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22, // Increased font size
                      fontWeight: FontWeight.w800, // Bolder
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We make sure you and your family\nenjoy the best, and grow the best.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12, // Increased font size
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WunzaColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Shop Now',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            // Image (Mocking the vegetables image)
            Positioned(
              right: -20,
              bottom: -20,
              child: SizedBox(
                width: 180,
                height: 180,
                child: CachedNetworkImage(
                  imageUrl: 'https://png.pngtree.com/png-clipart/20230123/original/pngtree-vegetables-basket-png-image_8927515.png', // Placeholder vegetable basket
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(),
                  errorWidget: (context, url, error) => const Icon(Icons.image, color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
