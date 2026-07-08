import 'package:flutter/material.dart';

/// One card's worth of content in a [DiscoverySection]. Placeholder data
/// only — see the Explore discovery hub design spec's non-goals for why
/// there's no repository/fetching here yet.
@immutable
class DiscoveryItem {
  const DiscoveryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tintColor,
    this.badge,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color tintColor;
  final String? badge;
}

/// One quick-category chip shown below the search bar and in the search
/// sheet's "Browse by category" section.
@immutable
class ExploreCategory {
  const ExploreCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const List<ExploreCategory> exploreCategories = [
  ExploreCategory(
      id: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag_outlined),
  ExploreCategory(
      id: 'services',
      label: 'Services',
      icon: Icons.miscellaneous_services_outlined),
  ExploreCategory(id: 'events', label: 'Events', icon: Icons.event_outlined),
  ExploreCategory(id: 'nearby', label: 'Nearby', icon: Icons.place_outlined),
  ExploreCategory(
      id: 'deals', label: 'Deals', icon: Icons.local_offer_outlined),
  ExploreCategory(
      id: 'community', label: 'Community', icon: Icons.groups_outlined),
];

const List<DiscoveryItem> trendingItems = [
  DiscoveryItem(
    id: 't1',
    title: 'Wireless earbuds',
    subtitle: '4.6 ★ · 2.1k sold',
    tintColor: Color(0xFFFF7A45),
  ),
  DiscoveryItem(
    id: 't2',
    title: 'Desk lamp',
    subtitle: '4.8 ★ · 890 sold',
    tintColor: Color(0xFF9B8CFF),
  ),
  DiscoveryItem(
    id: 't3',
    title: 'Running shoes',
    subtitle: '4.5 ★ · 3.4k sold',
    tintColor: Color(0xFFFF4D6D),
  ),
];

const List<DiscoveryItem> recommendedItems = [
  DiscoveryItem(
    id: 'r1',
    title: 'Weekend picks',
    subtitle: 'Curated for you',
    tintColor: Color(0xFF9B8CFF),
  ),
  DiscoveryItem(
    id: 'r2',
    title: 'Based on your history',
    subtitle: 'More like this',
    tintColor: Color(0xFFFF7A45),
  ),
  DiscoveryItem(
    id: 'r3',
    title: 'Similar to your saves',
    subtitle: 'You might like',
    tintColor: Color(0xFFFF4D6D),
  ),
];

const List<DiscoveryItem> businessItems = [
  DiscoveryItem(
    id: 'b1',
    title: 'Corner Cafe',
    subtitle: '4.7 ★ · 0.3 mi away',
    tintColor: Color(0xFFFF7A45),
  ),
  DiscoveryItem(
    id: 'b2',
    title: 'Green Market',
    subtitle: '4.4 ★ · 0.8 mi away',
    tintColor: Color(0xFF9B8CFF),
  ),
  DiscoveryItem(
    id: 'b3',
    title: 'Blue Bottle Roasters',
    subtitle: '4.9 ★ · 1.1 mi away',
    tintColor: Color(0xFFFF4D6D),
  ),
];

const List<DiscoveryItem> dealItems = [
  DiscoveryItem(
    id: 'd1',
    title: 'Accessories bundle',
    subtitle: 'Was \$40',
    tintColor: Color(0xFFFF7A45),
    badge: '20% off',
  ),
  DiscoveryItem(
    id: 'd2',
    title: 'Data top-up pack',
    subtitle: 'Limited time',
    tintColor: Color(0xFF9B8CFF),
    badge: '2x data',
  ),
  DiscoveryItem(
    id: 'd3',
    title: 'Voice bundle',
    subtitle: 'This week only',
    tintColor: Color(0xFFFF4D6D),
    badge: '15% off',
  ),
];

List<DiscoveryItem> get allDiscoveryItems => [
      ...trendingItems,
      ...recommendedItems,
      ...businessItems,
      ...dealItems,
    ];

const List<String> recentSearches = [
  'Wireless earbuds',
  'Corner Cafe',
  'Voice bundles',
  'Local events',
];

const List<String> trendingSearches = [
  'Running shoes',
  'Data top-up',
  'Green Market',
  'Split payments',
  'Desk lamp',
  'Nearby events',
];
