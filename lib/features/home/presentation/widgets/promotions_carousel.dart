import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/shopping/banner.dart' as shopping;

class GlidePromotionsCarousel extends StatefulWidget {
  const GlidePromotionsCarousel({
    super.key,
    this.onBannerTap,
    this.apiBanners = const [],
  });

  final void Function(int index)? onBannerTap;
  final List<shopping.Banner> apiBanners;

  @override
  State<GlidePromotionsCarousel> createState() =>
      _GlidePromotionsCarouselState();
}

class _GlidePromotionsCarouselState extends State<GlidePromotionsCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  static const _fallback = <_Promo>[
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

  bool get _hasApiBanners =>
      widget.apiBanners.isNotEmpty &&
      widget.apiBanners.any((b) => b.isActive);

  List<shopping.Banner> get _activeBanners =>
      widget.apiBanners.where((b) => b.isActive).toList();

  int get _count => _hasApiBanners ? _activeBanners.length : _fallback.length;

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
            itemCount: _count,
            onPageChanged: (i) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _page = i);
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => widget.onBannerTap?.call(index),
                  child: _hasApiBanners
                      ? _ApiBannerCard(banner: _activeBanners[index], height: h)
                      : _GradientBannerCard(promo: _fallback[index]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_count, (i) {
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

class _ApiBannerCard extends StatelessWidget {
  const _ApiBannerCard({required this.banner, required this.height});

  final shopping.Banner banner;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (banner.imageUrl.isNotEmpty)
            Image.network(
              banner.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          else
            _placeholder(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (banner.title.isNotEmpty)
                  Text(
                    banner.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (banner.description.isNotEmpty)
                  Text(
                    banner.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
          ),
        ),
      );
}

class _GradientBannerCard extends StatelessWidget {
  const _GradientBannerCard({required this.promo});

  final _Promo promo;

  @override
  Widget build(BuildContext context) {
    return Container(
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
