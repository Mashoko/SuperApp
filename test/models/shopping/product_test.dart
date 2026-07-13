import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';

void main() {
  group('Product.fromJson', () {
    test('parses the new fields when present', () {
      final product = Product.fromJson({
        '_id': 'p1',
        'name': 'Wireless earbuds',
        'price': 49.99,
        'discountPrice': 39.99,
        'averageRating': 4.6,
        'reviewCount': 128,
        'isTrending': true,
        'storeName': 'Acme Electronics',
        'verifiedSeller': true,
        'deliveryAvailable': true,
      });

      expect(product.discountPrice, 39.99);
      expect(product.averageRating, 4.6);
      expect(product.reviewCount, 128);
      expect(product.isTrending, true);
      expect(product.storeName, 'Acme Electronics');
      expect(product.verifiedSeller, true);
      expect(product.deliveryAvailable, true);
    });

    test('defaults the new fields safely when absent (pre-migration data)', () {
      final product = Product.fromJson({
        '_id': 'p1',
        'name': 'Legacy product',
        'price': 10.0,
      });

      expect(product.discountPrice, isNull);
      expect(product.averageRating, 0);
      expect(product.reviewCount, 0);
      expect(product.isTrending, false);
      expect(product.storeName, isNull);
      expect(product.verifiedSeller, false);
      expect(product.deliveryAvailable, false);
    });
  });
}
