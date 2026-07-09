import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import 'package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart';
import 'package:mvvm_sip_demo/features/home/presentation/views/composer_audio_view.dart';
import 'package:mvvm_sip_demo/features/home/presentation/views/composer_photo_video_view.dart';
import 'package:mvvm_sip_demo/features/home/presentation/views/composer_text_view.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/composer_bar.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/composer_choice_sheet.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/discovery_section.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_search_sheet.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/feed_post_card.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/feed_states.dart';
import 'package:mvvm_sip_demo/models/post.dart';
import 'package:mvvm_sip_demo/shared/widgets/maintenance_screen.dart';

/// The Explore tab: a pinned search bar, quick category chips, a banner
/// carousel, and 4 flagship [DiscoverySection]s (all on static placeholder
/// data — see the Explore discovery hub design spec), followed by a real
/// composer bar and an infinite-scrolling feed of [Post]s (see the Posts
/// Flutter UI design spec). The feed sits below the static sections so it
/// can scroll infinitely without stranding content beneath it.
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  String _selectedCategoryId = exploreCategories.first.id;
  String _userId = 'guest';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final creds = await getIt<OtpAuthService>().getStoredCredentials();
      if (!mounted) return;
      setState(() => _userId = creds?['username'] ?? 'guest');
      context.read<PostsViewModel>().loadFeed(_userId);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      context.read<PostsViewModel>().loadMore(_userId);
    }
  }

  String get _authorName {
    final alias = context.read<AccountSummaryViewModel>().alias;
    return (alias == null || alias.isEmpty) ? 'You' : alias;
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

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
        builder: (_) => MaintenanceScreen(label: label, icon: icon, color: color),
      ),
    );
  }

  void _openComposer() {
    ComposerChoiceSheet.show(context, (type) {
      final authorName = _authorName;
      switch (type) {
        case PostType.text:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComposerTextView(authorUserId: _userId, authorName: authorName),
            ),
          );
          break;
        case PostType.audio:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComposerAudioView(authorUserId: _userId, authorName: authorName),
            ),
          );
          break;
        case PostType.photo:
        case PostType.video:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComposerPhotoVideoView(
                type: type,
                authorUserId: _userId,
                authorName: authorName,
              ),
            ),
          );
          break;
      }
    });
  }

  void _confirmDelete(String postId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<PostsViewModel>().deletePost(postId, _userId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postsVM = context.watch<PostsViewModel>();

    return CustomScrollView(
      controller: _scrollController,
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
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 22),
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: ComposerBar(userInitials: _initialsFor(_authorName), onTap: _openComposer),
          ),
        ),
        if (postsVM.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: FeedLoadingSkeleton(),
            ),
          )
        else if (postsVM.error != null && postsVM.posts.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FeedErrorState(
                message: postsVM.error!,
                onRetry: () => postsVM.loadFeed(_userId),
              ),
            ),
          )
        else if (postsVM.posts.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FeedEmptyState(onCompose: _openComposer),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == postsVM.posts.length) {
                    if (postsVM.isLoadingMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!postsVM.hasMore) return const SizedBox.shrink();
                    return FeedLoadMoreRetry(onRetry: () => postsVM.loadMore(_userId));
                  }
                  final post = postsVM.posts[index];
                  return FeedPostCard(
                    post: post,
                    currentUserId: _userId,
                    onLikeTap: () => postsVM.toggleLike(post.id, _userId),
                    onCommentTap: () => _openMaintenance(
                      label: 'Comments',
                      icon: Icons.mode_comment_outlined,
                      color: WunzaColors.navIndicator,
                    ),
                    onDeleteTap:
                        post.authorUserId == _userId ? () => _confirmDelete(post.id) : null,
                  );
                },
                childCount: postsVM.posts.length + 1,
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
                child: Semantics(
                  button: true,
                  label: banner.title,
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
