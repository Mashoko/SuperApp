import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_product_section.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';

Product _product(String id) => Product(productId: id, name: 'Product $id', price: 10.0);

void main() {
  testWidgets('shows a shimmer placeholder row while loading', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExploreProductSection(
          title: 'Trending Now',
          subtitle: "What's popular right now",
          products: const [],
          isLoading: true,
          error: null,
          onRetry: () {},
          emptyTitle: 'No Trending Products Yet',
          emptyMessage: 'Check back later. New products are added every day.',
          emptyActionLabel: 'Browse Categories',
          onEmptyAction: () {},
          currentUserId: 'user1',
          isWishlisted: (_) => false,
          onFavoriteTap: (_) {},
          onProductTap: (_) {},
          onAddToCart: (_) {},
        ),
      ),
    ));

    expect(find.byKey(const Key('explore-product-section-shimmer')), findsOneWidget);
  });

  testWidgets('shows real product cards on success', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExploreProductSection(
          title: 'Trending Now',
          subtitle: "What's popular right now",
          products: [_product('p1'), _product('p2')],
          isLoading: false,
          error: null,
          onRetry: () {},
          emptyTitle: 'No Trending Products Yet',
          emptyMessage: 'Check back later. New products are added every day.',
          emptyActionLabel: 'Browse Categories',
          onEmptyAction: () {},
          currentUserId: 'user1',
          isWishlisted: (_) => false,
          onFavoriteTap: (_) {},
          onProductTap: (_) {},
          onAddToCart: (_) {},
        ),
      ),
    ));

    expect(find.text('Product p1'), findsOneWidget);
    expect(find.text('Product p2'), findsOneWidget);
  });

  testWidgets('shows the empty state with the given copy and action when there are no products',
      (tester) async {
    var actionTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExploreProductSection(
          title: 'Trending Now',
          subtitle: "What's popular right now",
          products: const [],
          isLoading: false,
          error: null,
          onRetry: () {},
          emptyTitle: 'No Trending Products Yet',
          emptyMessage: 'Check back later. New products are added every day.',
          emptyActionLabel: 'Browse Categories',
          onEmptyAction: () => actionTapped = true,
          currentUserId: 'user1',
          isWishlisted: (_) => false,
          onFavoriteTap: (_) {},
          onProductTap: (_) {},
          onAddToCart: (_) {},
        ),
      ),
    ));

    expect(find.text('No Trending Products Yet'), findsOneWidget);
    expect(find.text('Check back later. New products are added every day.'), findsOneWidget);
    await tester.tap(find.text('Browse Categories'));
    expect(actionTapped, true);
  });

  testWidgets('shows an error state with a working retry, never a blank space', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExploreProductSection(
          title: 'Trending Now',
          subtitle: "What's popular right now",
          products: const [],
          isLoading: false,
          error: 'Failed to load trending products. Check your connection and try again.',
          onRetry: () => retried = true,
          emptyTitle: 'No Trending Products Yet',
          emptyMessage: 'Check back later. New products are added every day.',
          emptyActionLabel: 'Browse Categories',
          onEmptyAction: () {},
          currentUserId: 'user1',
          isWishlisted: (_) => false,
          onFavoriteTap: (_) {},
          onProductTap: (_) {},
          onAddToCart: (_) {},
        ),
      ),
    ));

    expect(find.text('Failed to load trending products. Check your connection and try again.'),
        findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, true);
  });
}
