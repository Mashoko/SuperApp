import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/discovery_section.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_search_sheet.dart';
import 'package:mvvm_sip_demo/shared/widgets/maintenance_screen.dart';

/// The Explore tab's discovery hub: a pinned search bar, quick category
/// chips, a banner carousel, and 4 flagship [DiscoverySection]s — all on
/// static placeholder data. See the Explore discovery hub design spec for
/// what's deferred (the remaining ~8 carousels, real search, filtering,
/// tablet/desktop layouts, loading/error states, the social layer).
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  String _selectedCategoryId = exploreCategories.first.id;

  void _openSearchSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ExploreSearchSheet(),
      ),
    );
  }

  void _openMaintenance(
      {required String label, required IconData icon, required Color color}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MaintenanceScreen(label: label, icon: icon, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickySearchBarDelegate(
            onTap: _openSearchSheet,
            onFilterTap: () => _openMaintenance(
              label: 'Search filters',
              icon: Icons.tune,
              color: WunzaColors.navIndicator,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _QuickCategoriesRow(
                  selectedId: _selectedCategoryId,
                  onSelected: (id) => setState(() => _selectedCategoryId = id),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ExploreBannerCarousel(
                    onBannerTap: () => _openMaintenance(
                      label: 'Featured',
                      icon: Icons.campaign_outlined,
                      color: WunzaColors.padGradientStart,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DiscoverySection(
                        title: 'Trending Now',
                        subtitle: "What's popular right now",
                        items: trendingItems,
                        onSeeAll: () => _openMaintenance(
                          label: 'Trending Now',
                          icon: Icons.local_fire_department_outlined,
                          color: WunzaColors.padGradientStart,
                        ),
                      ),
                      DiscoverySection(
                        title: 'Recommended Products',
                        subtitle: 'Picked for you',
                        items: recommendedItems,
                        onSeeAll: () => _openMaintenance(
                          label: 'Recommended Products',
                          icon: Icons.auto_awesome_outlined,
                          color: WunzaColors.navIndicator,
                        ),
                      ),
                      DiscoverySection(
                        title: 'Popular Businesses',
                        subtitle: 'Storefronts people love',
                        items: businessItems,
                        onSeeAll: () => _openMaintenance(
                          label: 'Popular Businesses',
                          icon: Icons.storefront_outlined,
                          color: WunzaColors.padGradientEnd,
                        ),
                      ),
                      DiscoverySection(
                        title: 'Deals & Promotions',
                        subtitle: 'Limited-time offers',
                        items: dealItems,
                        onSeeAll: () => _openMaintenance(
                          label: 'Deals & Promotions',
                          icon: Icons.local_offer_outlined,
                          color: WunzaColors.padGradientStart,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  _StickySearchBarDelegate({required this.onTap, required this.onFilterTap});

  final VoidCallback onTap;
  final VoidCallback onFilterTap;

  static const double _height = 64;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Semantics(
        button: true,
        label: 'Search',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).hintColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search products, businesses, events, services, people...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).hintColor),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Filter',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onFilterTap,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.tune,
                          color: Theme.of(context).hintColor, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) {
    return oldDelegate.onTap != onTap || oldDelegate.onFilterTap != onFilterTap;
  }
}

class _QuickCategoriesRow extends StatelessWidget {
  const _QuickCategoriesRow(
      {required this.selectedId, required this.onSelected});

  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: exploreCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = exploreCategories[i];
          final selected = category.id == selectedId;
          return ChoiceChip(
            avatar: Icon(category.icon, size: 16),
            label: Text(category.label),
            selected: selected,
            selectedColor: WunzaColors.navIndicator.withValues(alpha: 0.18),
            onSelected: (_) => onSelected(category.id),
          );
        },
      ),
    );
  }
}

class _ExploreBanner {
  const _ExploreBanner(
      {required this.title, required this.subtitle, required this.colors});
  final String title;
  final String subtitle;
  final List<Color> colors;
}

const List<_ExploreBanner> _banners = [
  _ExploreBanner(
    title: 'Refer a friend',
    subtitle: 'Give \$5, get \$5 when they join',
    colors: [WunzaColors.padGradientStart, WunzaColors.padGradientEnd],
  ),
  _ExploreBanner(
    title: 'New: Split payments',
    subtitle: 'Send money together with friends',
    colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
  ),
  _ExploreBanner(
    title: 'Explore local events',
    subtitle: 'Discover things happening near you',
    colors: [Color(0xFF283593), Color(0xFF5C6BC0)],
  ),
];

class _ExploreBannerCarousel extends StatefulWidget {
  const _ExploreBannerCarousel({required this.onBannerTap});
  final VoidCallback onBannerTap;

  @override
  State<_ExploreBannerCarousel> createState() =>
      _ExploreBannerCarouselState();
}

class _ExploreBannerCarouselState extends State<_ExploreBannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: widget.onBannerTap,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: banner.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: banner.colors.last.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          banner.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          banner.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
              key: Key('banner-dot-$i'),
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? WunzaColors.navIndicator
                    : WunzaColors.navIndicator.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
