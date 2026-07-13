import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_card.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';

Product _product({
  double price = 50.0,
  double? discountPrice,
  double averageRating = 0,
  int reviewCount = 0,
  bool verifiedSeller = false,
  bool deliveryAvailable = false,
  String? storeName,
}) {
  return Product(
    productId: 'p1',
    name: 'Wireless earbuds',
    price: price,
    discountPrice: discountPrice,
    averageRating: averageRating,
    reviewCount: reviewCount,
    verifiedSeller: verifiedSeller,
    deliveryAvailable: deliveryAvailable,
    storeName: storeName,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SizedBox(height: 260, child: child)));

void main() {
  testWidgets('shows no rating row when reviewCount is 0', (tester) async {
    await tester.pumpWidget(_wrap(ProductCard(
      product: _product(),
      isFavorited: false,
    )));

    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('shows the rating and review count when reviewCount > 0', (tester) async {
    await tester.pumpWidget(_wrap(ProductCard(
      product: _product(averageRating: 4.6, reviewCount: 128),
      isFavorited: false,
    )));

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.textContaining('4.6'), findsOneWidget);
    expect(find.textContaining('128'), findsOneWidget);
  });

  testWidgets('shows a verified-seller badge when verifiedSeller is true', (tester) async {
    await tester.pumpWidget(_wrap(ProductCard(
      product: _product(verifiedSeller: true),
      isFavorited: false,
    )));

    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('omits the verified-seller badge when verifiedSeller is false', (tester) async {
    await tester.pumpWidget(_wrap(ProductCard(
      product: _product(verifiedSeller: false),
      isFavorited: false,
    )));

    expect(find.byIcon(Icons.verified), findsNothing);
  });

  testWidgets('shows a delivery indicator when deliveryAvailable is true', (tester) async {
    await tester.pumpWidget(_wrap(ProductCard(
      product: _product(deliveryAvailable: true),
      isFavorited: false,
    )));

    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('shows a discount badge and struck-through original price when discounted', (tester) async {
    await tester.pumpWidget(_wrap(ProductCard(
      product: _product(price: 50.0, discountPrice: 40.0),
      isFavorited: false,
    )));

    expect(find.textContaining('20%'), findsOneWidget);
  });

  testWidgets('shows the store name when present', (tester) async {
    await tester.pumpWidget(_wrap(ProductCard(
      product: _product(storeName: 'Acme Electronics'),
      isFavorited: false,
    )));

    expect(find.text('Acme Electronics'), findsOneWidget);
  });

  testWidgets('favourite icon reflects isFavorited', (tester) async {
    await tester.pumpWidget(_wrap(ProductCard(
      product: _product(),
      isFavorited: true,
    )));

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}
