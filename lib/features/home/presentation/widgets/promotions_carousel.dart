import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class GlidePromotionsCarousel extends StatefulWidget {
  const GlidePromotionsCarousel({super.key, this.onBannerTap});

  final void Function(int index)? onBannerTap;

  @override
  State<GlidePromotionsCarousel> createState() =>
      _GlidePromotionsCarouselState();
}

class _GlidePromotionsCarouselState extends State<GlidePromotionsCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  static const _banners = <_Promo>[
    _Promo(
      title: 'Voice bundles',
      subtitle: 'Extra minutes — valid 30 days',
      colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
    ),
    _Promo(
      title: 'Shop flash sale',
      subtitle: 'Up to 25% off accessories',
      colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
    ),
    _Promo(
      title: 'Data boost',
      subtitle: 'Add-on packs for heavy usage',
      colors: [Color(0xFF283593), Color(0xFF5C6BC0)],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.of(context).size.height * 0.16).clamp(120.0, 160.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Promotions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: h,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final promo = _banners[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onBannerTap?.call(index),
                    borderRadius: BorderRadius.circular(20),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: promo.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: promo.colors.last.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              promo.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              promo.subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? WunzaColors.glideAccent
                    : WunzaColors.glidePrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Promo {
  const _Promo({
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
}
