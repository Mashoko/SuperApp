import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mvvm_sip_demo/services/shopping_service.dart';

Map<String, dynamic> _productJson({String id = 'p1', String name = 'Product'}) => {
      '_id': id,
      'name': name,
      'price': 10.0,
    };

void main() {
  group('fetchProducts', () {
    test('returns ok: true and parses products on a successful response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'products': [_productJson()],
            'totalPages': 2,
            'currentPage': 1,
            'totalProducts': 15,
          }),
          200,
        );
      });
      final service = ShoppingService(client: mockClient);

      final result = await service.fetchProducts();

      expect(result.ok, true);
      expect(result.products, hasLength(1));
      expect(result.totalPages, 2);
    });

    test('returns ok: false on a non-200 response', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = ShoppingService(client: mockClient);

      final result = await service.fetchProducts();

      expect(result.ok, false);
      expect(result.products, isEmpty);
    });
  });

  group('fetchTrendingProducts', () {
    test('sends sort=trending and returns ok: true on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['sort'], 'trending');
        return http.Response(
          json.encode({
            'products': [_productJson(id: 't1')],
            'totalPages': 1,
            'currentPage': 1,
            'totalProducts': 1,
          }),
          200,
        );
      });
      final service = ShoppingService(client: mockClient);

      final result = await service.fetchTrendingProducts();

      expect(result.ok, true);
      expect(result.products.single.productId, 't1');
    });

    test('returns ok: false on failure', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = ShoppingService(client: mockClient);

      final result = await service.fetchTrendingProducts();

      expect(result.ok, false);
      expect(result.products, isEmpty);
    });
  });

  group('fetchRecommendedProducts', () {
    test('sends sort=recommended and userId, returns ok: true on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['sort'], 'recommended');
        expect(request.url.queryParameters['userId'], 'user1');
        return http.Response(
          json.encode({
            'products': [_productJson(id: 'r1')],
            'totalPages': 1,
            'currentPage': 1,
            'totalProducts': 1,
          }),
          200,
        );
      });
      final service = ShoppingService(client: mockClient);

      final result = await service.fetchRecommendedProducts(userId: 'user1');

      expect(result.ok, true);
      expect(result.products.single.productId, 'r1');
    });

    test('returns ok: false on failure', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = ShoppingService(client: mockClient);

      final result = await service.fetchRecommendedProducts(userId: 'user1');

      expect(result.ok, false);
    });
  });

  group('wishlist', () {
    test('fetchWishlist parses a list of products', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/wishlist');
        expect(request.url.queryParameters['userId'], 'user1');
        return http.Response(json.encode([_productJson(id: 'w1')]), 200);
      });
      final service = ShoppingService(client: mockClient);

      final products = await service.fetchWishlist('user1');

      expect(products.single.productId, 'w1');
    });

    test('fetchWishlist returns an empty list on failure', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = ShoppingService(client: mockClient);

      final products = await service.fetchWishlist('user1');

      expect(products, isEmpty);
    });

    test('addToWishlist completes without throwing on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/wishlist/add');
        return http.Response(json.encode({'message': 'Added to wishlist'}), 200);
      });
      final service = ShoppingService(client: mockClient);

      await expectLater(service.addToWishlist('user1', 'p1'), completes);
    });

    test('addToWishlist throws on a non-200 response', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = ShoppingService(client: mockClient);

      expect(() => service.addToWishlist('user1', 'p1'), throwsA(isA<Exception>()));
    });

    test('removeFromWishlist completes without throwing on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/wishlist/remove/p1');
        return http.Response(json.encode({'message': 'Removed from wishlist'}), 200);
      });
      final service = ShoppingService(client: mockClient);

      await expectLater(service.removeFromWishlist('user1', 'p1'), completes);
    });

    test('removeFromWishlist throws on a non-200 response', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = ShoppingService(client: mockClient);

      expect(() => service.removeFromWishlist('user1', 'p1'), throwsA(isA<Exception>()));
    });
  });
}
