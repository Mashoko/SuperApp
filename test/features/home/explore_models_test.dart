import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart';

void main() {
  test('exploreCategories has non-empty ids and labels', () {
    expect(exploreCategories, isNotEmpty);
    for (final c in exploreCategories) {
      expect(c.id, isNotEmpty);
      expect(c.label, isNotEmpty);
    }
  });

  test('all four flagship item lists are non-empty', () {
    expect(trendingItems, isNotEmpty);
    expect(recommendedItems, isNotEmpty);
    expect(businessItems, isNotEmpty);
    expect(dealItems, isNotEmpty);
  });

  test('every deal item has a badge', () {
    for (final item in dealItems) {
      expect(item.badge, isNotNull);
    }
  });

  test('allDiscoveryItems concatenates all four flagship lists in order', () {
    expect(
      allDiscoveryItems.length,
      trendingItems.length +
          recommendedItems.length +
          businessItems.length +
          dealItems.length,
    );
    expect(allDiscoveryItems.first.id, trendingItems.first.id);
    expect(allDiscoveryItems.last.id, dealItems.last.id);
  });

  test('recentSearches and trendingSearches are non-empty', () {
    expect(recentSearches, isNotEmpty);
    expect(trendingSearches, isNotEmpty);
  });
}
