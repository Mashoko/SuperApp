# Explore: Real Trending + Recommended Products Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Explore tab's hardcoded "Trending Now" / "Recommended Products" placeholder cards with real `Product` data, each section independently fetched with real loading (shimmer)/success/empty/error states, plus a real, persisted wishlist (favourite button).

**Architecture:** Extend the existing `Product` schema (backend + Flutter) with rating/trending/store/verified/delivery fields; extend the existing `GET /api/products` route with `sort=trending`/`sort=recommended` query params (reusing its pagination/filter logic, not duplicating it); extend the existing `ShoppingService`/`ShoppingViewModel`/`ProductCard` rather than building parallel ones; add one new Explore-specific section widget that renders shimmer/error/empty/real-cards based on `ShoppingViewModel` state.

**Tech Stack:** Flutter (existing `http`, `provider`, `get_it`, `cached_network_image`), Node/Express/Mongoose (existing `mongodb-memory-server` + Jest + Supertest test setup).

## Global Constraints

- `ShoppingService`'s new/converted methods must never throw on read failures (`fetchProducts`, `fetchTrendingProducts`, `fetchRecommendedProducts`, `fetchWishlist` all silent-fallback to an empty result) — this is a deliberate, existing convention. Every one of these methods' return value MUST carry an explicit `ok: bool` (or, for `fetchWishlist`, be a plain list with no ambiguity since an empty wishlist and a failed fetch are already indistinguishable in the existing code and that is unchanged by this plan). **Never** have a ViewModel method wrap one of these calls in `try/catch` expecting a throw — branch on the returned `ok` flag instead. (This exact mismatch — a service that never throws paired with a ViewModel that assumed it did — was a Critical bug caught in this app's Posts feature; do not reintroduce it here.)
- `addToWishlist`/`removeFromWishlist` DO throw on failure (write actions) — matching `PostsService.createPost`/`toggleLike`/`deletePost`'s convention exactly. `ShoppingViewModel.toggleWishlist` catches and reverts, exactly like `PostsViewModel.toggleLike`.
- No new pub packages. Shimmer loading reuses the existing `lib/shared/widgets/shimmer_widget.dart` (`ShimmerWidget`) — do not add the `shimmer` package or any other new dependency.
- `ProductCard` (`lib/features/shopping/presentation/views/widgets/product_card.dart`) is extended, not replaced or forked. All new rows (rating, verified badge, delivery indicator, discount badge, store name) must be purely additive and conditional — the existing Shopping-tab grid usage of this widget must keep compiling and rendering exactly as before for products that don't carry the new fields.
- The other two existing `DiscoverySection`s on Explore (Popular Businesses, Deals & Promotions) are NOT touched by this plan — they remain on `explore_models.dart` placeholder data until their own future specs. Only the "Trending Now" and "Recommended Products" sections are replaced.
- Every new backend test uses the existing `mongodb-memory-server` + Jest + Supertest pattern already established in `backend/tests/` (see `posts.feed.test.js` for the exact boilerplate: `beforeAll` spins up `MongoMemoryServer`, sets `process.env.MONGO_URI`, requires `../index`; `afterAll` disconnects and stops the server; `afterEach` clears collections).
- Every new Flutter service test uses `package:http/testing.dart`'s `MockClient` — no live network calls. Every new ViewModel test uses a fake service implementing `ShoppingService`'s interface — no live network calls, no real `ShoppingService`.

---

### Task 1: Backend — Product schema fields + `GET /api/products` sort=trending/recommended

**Files:**
- Modify: `backend/models/product.model.js`
- Modify: `backend/index.js` (the `GET /api/products` route only, lines 177-209)
- Test: `backend/tests/products.sort.test.js`

**Interfaces:**
- Produces: `Product` schema fields `averageRating`, `reviewCount`, `isTrending`, `storeName`, `verifiedSeller`, `deliveryAvailable`. `GET /api/products?sort=trending` and `GET /api/products?sort=recommended&userId=<id>` — both return the exact same `{ products, totalPages, currentPage, totalProducts }` shape the route already returns today. Consumed by Task 2 (Flutter model) and Task 3 (`ShoppingService`).

- [ ] **Step 1: Add the new fields to the Product schema**

In `backend/models/product.model.js`, insert these six fields right after the existing `isAvailable` field and before `isDeleted`:

```js
    averageRating: {
        type: Number,
        default: 0,
        min: 0,
        max: 5
    },
    reviewCount: {
        type: Number,
        default: 0
    },
    isTrending: {
        type: Boolean,
        default: false
    },
    storeName: {
        type: String,
        required: false
    },
    verifiedSeller: {
        type: Boolean,
        default: false
    },
    deliveryAvailable: {
        type: Boolean,
        default: false
    },
```

The full file becomes:

```js
const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
    },
    description: {
        type: String,
        required: false,
    },
    price: {
        type: Number,
        required: true,
    },
    imageUrl: {
        type: String,
        required: false,
    },
    category: {
        type: String,
        required: false,
    },
    stock: {
        type: Number,
        default: 0
    },
    discountPrice: {
        type: Number,
        required: false
    },
    isAvailable: {
        type: Boolean,
        default: true
    },
    averageRating: {
        type: Number,
        default: 0,
        min: 0,
        max: 5
    },
    reviewCount: {
        type: Number,
        default: 0
    },
    isTrending: {
        type: Boolean,
        default: false
    },
    storeName: {
        type: String,
        required: false
    },
    verifiedSeller: {
        type: Boolean,
        default: false
    },
    deliveryAvailable: {
        type: Boolean,
        default: false
    },
    isDeleted: {
        type: Boolean,
        default: false
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
});

module.exports = mongoose.model('Product', productSchema);
```

- [ ] **Step 2: Write the failing tests**

Create `backend/tests/products.sort.test.js`:

```js
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;
let app;
let Product;
let Wishlist;
let Cart;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  process.env.MONGO_URI = mongoServer.getUri();
  app = require('../index');
  await new Promise((resolve) => {
    if (mongoose.connection.readyState === 1) return resolve();
    mongoose.connection.once('open', resolve);
  });
  Product = require('../models/product.model');
  Wishlist = require('../models/wishlist.model');
  Cart = require('../models/cart.model');
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await Product.deleteMany({});
  await Wishlist.deleteMany({});
  await Cart.deleteMany({});
});

describe('GET /api/products?sort=trending', () => {
  test('returns only isTrending products sorted by rating descending', async () => {
    await Product.create({ name: 'A', price: 10, isTrending: true, averageRating: 3.5 });
    await Product.create({ name: 'B', price: 10, isTrending: true, averageRating: 4.8 });
    await Product.create({ name: 'C', price: 10, isTrending: false, averageRating: 5.0 });

    const res = await request(app).get('/api/products?sort=trending');

    expect(res.status).toBe(200);
    expect(res.body.products).toHaveLength(2);
    expect(res.body.products.map((p) => p.name)).toEqual(['B', 'A']);
  });

  test('returns an empty list (not an error) when no products are trending', async () => {
    await Product.create({ name: 'A', price: 10, isTrending: false });

    const res = await request(app).get('/api/products?sort=trending');

    expect(res.status).toBe(200);
    expect(res.body.products).toEqual([]);
    expect(res.body.totalProducts).toBe(0);
  });
});

describe('GET /api/products?sort=recommended', () => {
  test('recommends products in the same category as the user\'s wishlist, excluding wishlist/cart items', async () => {
    const wishlisted = await Product.create({ name: 'Wishlisted', price: 10, category: 'Shoes' });
    await Product.create({ name: 'Same category', price: 20, category: 'Shoes', averageRating: 4.0 });
    const inCart = await Product.create({ name: 'In cart', price: 15, category: 'Shoes', averageRating: 4.9 });
    await Product.create({ name: 'Other category', price: 30, category: 'Lamps' });

    await Wishlist.create({ userId: 'user1', productIds: [wishlisted._id] });
    await Cart.create({ userId: 'user1', items: [{ productId: inCart._id, quantity: 1 }] });

    const res = await request(app).get('/api/products?sort=recommended&userId=user1');

    expect(res.status).toBe(200);
    const names = res.body.products.map((p) => p.name);
    expect(names).toEqual(['Same category']);
  });

  test('falls back to newest-first when the user has no wishlist items', async () => {
    await Product.create({ name: 'Older', price: 10 });
    await new Promise((resolve) => setTimeout(resolve, 10));
    await Product.create({ name: 'Newer', price: 10 });

    const res = await request(app).get('/api/products?sort=recommended&userId=newuser');

    expect(res.status).toBe(200);
    expect(res.body.products.map((p) => p.name)).toEqual(['Newer', 'Older']);
  });

  test('falls back to newest-first when no userId is supplied', async () => {
    await Product.create({ name: 'Older', price: 10 });
    await new Promise((resolve) => setTimeout(resolve, 10));
    await Product.create({ name: 'Newer', price: 10 });

    const res = await request(app).get('/api/products?sort=recommended');

    expect(res.status).toBe(200);
    expect(res.body.products.map((p) => p.name)).toEqual(['Newer', 'Older']);
  });
});

describe('GET /api/products (no sort param)', () => {
  test('existing pagination/category/search behavior is unchanged', async () => {
    await Product.create({ name: 'A', price: 10, category: 'Shoes' });
    await Product.create({ name: 'B', price: 10, category: 'Lamps' });

    const res = await request(app).get('/api/products?category=Shoes');

    expect(res.status).toBe(200);
    expect(res.body.products).toHaveLength(1);
    expect(res.body.products[0].name).toBe('A');
  });
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd backend && npx jest tests/products.sort.test.js`
Expected: FAIL — `sort=trending`/`sort=recommended` don't filter/sort yet (the route ignores the `sort` param entirely today), so all 4 new-behavior tests fail; only the last ("no sort param") test passes since it exercises unchanged behavior.

- [ ] **Step 4: Modify the `GET /api/products` route**

In `backend/index.js`, replace the entire existing route (lines 177-209) with:

```js
app.get('/api/products', async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const skip = (page - 1) * limit;

        const filter = { isDeleted: false };
        if (req.query.category && req.query.category !== 'All') {
            filter.category = req.query.category;
        }
        if (req.query.search && req.query.search.trim() !== '') {
            const escaped = req.query.search.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const searchRegex = new RegExp(escaped, 'i');
            filter.$or = [{ name: searchRegex }, { description: searchRegex }];
        }

        let sort = null;

        if (req.query.sort === 'trending') {
            filter.isTrending = true;
            sort = { averageRating: -1, createdAt: -1 };
        } else if (req.query.sort === 'recommended') {
            const userId = req.query.userId;
            let categories = [];
            let excludeIds = [];

            if (userId) {
                const wishlist = await Wishlist.findOne({ userId });
                const wishlistProductIds = wishlist
                    ? wishlist.productIds.map((id) => id.toString())
                    : [];
                const cart = await Cart.findOne({ userId });
                const cartProductIds = cart
                    ? cart.items.map((item) => item.productId.toString())
                    : [];
                excludeIds = [...new Set([...wishlistProductIds, ...cartProductIds])];

                if (wishlistProductIds.length > 0) {
                    const wishlistProducts = await Product.find({
                        _id: { $in: wishlistProductIds },
                    });
                    categories = [
                        ...new Set(wishlistProducts.map((p) => p.category).filter(Boolean)),
                    ];
                }
            }

            if (categories.length > 0) {
                filter.category = { $in: categories };
            }
            if (excludeIds.length > 0) {
                filter._id = { $nin: excludeIds };
            }
            sort =
                categories.length > 0
                    ? { averageRating: -1, createdAt: -1 }
                    : { createdAt: -1, averageRating: -1 };
        }

        const totalProducts = await Product.countDocuments(filter);
        const totalPages = Math.ceil(totalProducts / limit);

        let query = Product.find(filter);
        if (sort) query = query.sort(sort);
        const products = await query.skip(skip).limit(limit);

        res.json({
            products,
            totalPages,
            currentPage: page,
            totalProducts
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});
```

This is purely additive: when `req.query.sort` is absent, `sort` stays `null`, no `.sort()` call is added to the query, and behavior is byte-identical to today. `Wishlist` and `Cart` are referenced here even though their `const` declarations appear later in `index.js` (lines 709 and 501) — this is safe because the whole module finishes loading (all `const`s initialized) before any HTTP request is ever handled; the route handler is a closure over the module scope, resolved at call time, not definition time. This is the same reason `Post` (declared at line 843) can be safely used inside routes defined earlier in the file, which this codebase already does implicitly.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && npx jest tests/products.sort.test.js`
Expected: PASS (6 tests).

- [ ] **Step 6: Run the full backend suite to confirm no regressions**

Run: `cd backend && npx jest`
Expected: PASS (all suites, previous 23 tests + 6 new = 29 tests).

- [ ] **Step 7: Commit**

```bash
git add backend/models/product.model.js backend/index.js backend/tests/products.sort.test.js
git commit -m "feat(products): add rating/trending/store fields and sort=trending|recommended"
```

---

### Task 2: Flutter — `Product` model fields

**Files:**
- Modify: `lib/models/shopping/product.dart`
- Test: `test/models/shopping/product_test.dart`

**Interfaces:**
- Consumes: nothing new (existing `Product` class).
- Produces: `Product` gains `discountPrice`, `averageRating`, `reviewCount`, `isTrending`, `storeName`, `verifiedSeller`, `deliveryAvailable` fields (all defaulted/nullable — existing call sites keep compiling unchanged). Consumed by Task 3 (`ShoppingService.fetchTrendingProducts`/`fetchRecommendedProducts`/`fetchWishlist` parse into these), Task 5 (`ProductCard` reads them).

- [ ] **Step 1: Write the failing tests**

Create `test/models/shopping/product_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/shopping/product_test.dart`
Expected: FAIL — `Product` has no such fields/named constructor args yet.

- [ ] **Step 3: Add the fields to `Product`**

Replace the full contents of `lib/models/shopping/product.dart` with:

```dart
enum ProductViewMode { extraSmall, small, medium, large }

class Product {
  final String productId;
  final String name;
  final double price;
  final String description;
  final int stock;
  final String category;
  final String imageUrl;
  final DateTime createdAt;
  final String unit;
  final double? discountPrice;
  final double averageRating;
  final int reviewCount;
  final bool isTrending;
  final String? storeName;
  final bool verifiedSeller;
  final bool deliveryAvailable;

  Product({
    required this.productId,
    required this.name,
    required this.price,
    this.description = '',
    this.stock = 0,
    this.category = '',
    this.imageUrl = '',
    this.unit = 'kg',
    DateTime? createdAt,
    this.discountPrice,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.isTrending = false,
    this.storeName,
    this.verifiedSeller = false,
    this.deliveryAvailable = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'description': description,
      'stock': stock,
      'category': category,
      'image_url': imageUrl,
      'unit': unit,
      'created_at': createdAt.toIso8601String(),
      'discountPrice': discountPrice,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'isTrending': isTrending,
      'storeName': storeName,
      'verifiedSeller': verifiedSeller,
      'deliveryAvailable': deliveryAvailable,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['_id'] ?? json['product_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      stock: (json['stock'] != null && json['stock'] is int && json['stock'] > 0) ? json['stock'] : 100,
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      unit: json['unit'] ?? 'kg',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      discountPrice: (json['discountPrice'] as num?)?.toDouble(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      isTrending: json['isTrending'] as bool? ?? false,
      storeName: json['storeName'] as String?,
      verifiedSeller: json['verifiedSeller'] as bool? ?? false,
      deliveryAvailable: json['deliveryAvailable'] as bool? ?? false,
    );
  }
}
```

Note: the `createdAt` parsing (`json['created_at']`, snake_case) is untouched from the original file — it's a pre-existing mismatch with the backend's actual `createdAt` (camelCase) field name, and out of scope for this plan to fix.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/shopping/product_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/shopping/product.dart test/models/shopping/product_test.dart
git commit -m "feat(products): add rating/trending/store fields to the Flutter Product model"
```

---

### Task 3: `ShoppingService` — injectable client, `ok`-flagged reads, trending/recommended/wishlist methods

**Files:**
- Modify: `lib/services/shopping_service.dart`
- Test: `test/services/shopping_service_test.dart`

**Interfaces:**
- Consumes: `Product.fromJson` (Task 2).
- Produces: `ShoppingService({http.Client? client})` (injectable, defaults to a real client — matches `PostsService`'s established pattern). `fetchProducts` now returns `({List<Product> products, int totalPages, bool ok})` (added `ok`). New: `fetchTrendingProducts({int page, int limit})`, `fetchRecommendedProducts({required String userId, int page, int limit})` — both returning the same `({List<Product> products, int totalPages, bool ok})` shape. New: `fetchWishlist(String userId) -> Future<List<Product>>`, `addToWishlist(String userId, String productId) -> Future<void>` (throws on failure), `removeFromWishlist(String userId, String productId) -> Future<void>` (throws on failure). Consumed by Task 4 (`ShoppingViewModel`).

- [ ] **Step 1: Write the failing tests**

Create `test/services/shopping_service_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/shopping_service_test.dart`
Expected: FAIL — `ShoppingService` has no injectable constructor, no `ok` field, and none of the new methods exist yet.

- [ ] **Step 3: Rewrite `shopping_service.dart`**

Replace the full contents of `lib/services/shopping_service.dart` with:

```dart
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/banner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ShoppingService {
  ShoppingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base = 'https://superapp-diht.onrender.com/api';

  // ── Product catalog (in-memory cache for browse) ──────────────────────────
  final Map<String, Product> _products = {};

  Future<({List<Product> products, int totalPages, bool ok})> fetchProducts({
    int page = 1,
    int limit = 10,
    String? category,
    String? search,
  }) async {
    try {
      final params = <String, String>{
        'page': '$page',
        'limit': '$limit',
      };
      if (category != null && category != 'All') params['category'] = category;
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

      final uri = Uri.parse('$_base/products').replace(queryParameters: params);
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        List<dynamic> productList;
        int totalPages = 1;

        if (decoded is List) {
          productList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          productList = decoded['products'] ?? [];
          totalPages = decoded['totalPages'] ?? 1;
        } else {
          return (products: <Product>[], totalPages: 0, ok: false);
        }

        final List<Product> newProducts = [];
        for (final item in productList) {
          final product = Product.fromJson(item);
          _products[product.productId] = product;
          newProducts.add(product);
        }
        return (products: newProducts, totalPages: totalPages, ok: true);
      } else {
        return (products: <Product>[], totalPages: 0, ok: false);
      }
    } catch (e) {
      return (products: <Product>[], totalPages: 0, ok: false);
    }
  }

  Future<({List<Product> products, int totalPages, bool ok})> fetchTrendingProducts({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse('$_base/products').replace(queryParameters: {
        'sort': 'trending',
        'page': '$page',
        'limit': '$limit',
      });
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final productList = decoded['products'] as List<dynamic>? ?? [];
        final totalPages = decoded['totalPages'] as int? ?? 1;
        return (
          products: productList.map((item) => Product.fromJson(item)).toList(),
          totalPages: totalPages,
          ok: true,
        );
      }
      return (products: <Product>[], totalPages: 0, ok: false);
    } catch (e) {
      return (products: <Product>[], totalPages: 0, ok: false);
    }
  }

  Future<({List<Product> products, int totalPages, bool ok})> fetchRecommendedProducts({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse('$_base/products').replace(queryParameters: {
        'sort': 'recommended',
        'userId': userId,
        'page': '$page',
        'limit': '$limit',
      });
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final productList = decoded['products'] as List<dynamic>? ?? [];
        final totalPages = decoded['totalPages'] as int? ?? 1;
        return (
          products: productList.map((item) => Product.fromJson(item)).toList(),
          totalPages: totalPages,
          ok: true,
        );
      }
      return (products: <Product>[], totalPages: 0, ok: false);
    } catch (e) {
      return (products: <Product>[], totalPages: 0, ok: false);
    }
  }

  Future<List<String>> fetchCategories() async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/categories?hasProducts=true'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => j['name'].toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Banner>> fetchBanners() async {
    try {
      final response = await _client.get(Uri.parse('$_base/banners'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Banner.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Product? getProduct(String productId) => _products[productId];

  // ── Cart (server-side) ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchCart(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/cart?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<Map<String, dynamic>> addToCart(String userId, String productId,
      {int quantity = 1}) async {
    try {
      final response = await _client.post(
        Uri.parse('$_base/cart/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<Map<String, dynamic>> updateCartQuantity(
      String userId, String productId, int quantity) async {
    if (quantity <= 0) return removeFromCart(userId, productId);
    try {
      final response = await _client.put(
        Uri.parse('$_base/cart/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<Map<String, dynamic>> removeFromCart(
      String userId, String productId) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$_base/cart/remove'));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'userId': userId, 'productId': productId});
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return _emptyCart(userId);
    } catch (e) {
      return _emptyCart(userId);
    }
  }

  Future<void> clearCart(String userId) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$_base/cart/clear'));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'userId': userId});
      final streamedResponse = await _client.send(request);
      await http.Response.fromStream(streamedResponse);
    } catch (_) {}
  }

  Map<String, dynamic> _emptyCart(String userId) => {
        'user_id': userId,
        'items': <dynamic>[],
        'total': 0.0,
        'item_count': 0,
      };

  // ── Orders (server-side) ──────────────────────────────────────────────────

  Future<Order?> placeOrder(
    String userId,
    String shippingAddress, {
    String? transactionId,
    String paymentStatus = 'pending',
    double discountAmount = 0.0,
    String? discountCode,
    required Map<String, dynamic> cartSnapshot,
  }) async {
    try {
      final cartItems = cartSnapshot['items'] as List<dynamic>? ?? [];
      final total = (cartSnapshot['total'] as num?)?.toDouble() ?? 0.0;

      final itemsPayload = cartItems.map((item) {
        final productData = item['product'] as Map<String, dynamic>;
        final quantity = item['quantity'] as int;
        final itemTotal = (item['total'] as num?)?.toDouble() ?? 0.0;
        return {
          'product': productData,
          'quantity': quantity,
          'total': itemTotal,
        };
      }).toList();

      final response = await _client.post(
        Uri.parse('$_base/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'items': itemsPayload,
          'shippingAddress': shippingAddress,
          'transactionId': transactionId,
          'paymentStatus': paymentStatus,
          'total': total - discountAmount,
          'discountCode': discountCode,
          'discountAmount': discountAmount,
        }),
      );

      if (response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return Order.fromJson(decoded);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Order>> fetchOrders(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/orders?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Order.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Wishlist ──────────────────────────────────────────────────────────────

  Future<int> fetchWishlistCount(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/wishlist?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.length;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Product>> fetchWishlist(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_base/wishlist?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Product.fromJson(j)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> addToWishlist(String userId, String productId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_base/wishlist/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'productId': productId}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to add to wishlist');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> removeFromWishlist(String userId, String productId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_base/wishlist/remove/$productId')
            .replace(queryParameters: {'userId': userId}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to remove from wishlist');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Voucher ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> validateVoucher(
      String code, double total) async {
    try {
      final response = await _client.post(
        Uri.parse('$_base/validate-voucher'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': code, 'cart_total': total}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Invalid voucher');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
```

This converts every existing method from the top-level `http.get`/`http.post`/`http.put`/`request.send()` calls to the injected `_client`'s equivalents — a purely mechanical, behavior-preserving change (an `http.Client`'s instance methods are what the package's top-level convenience functions delegate to internally). No existing method's request construction, headers, body, or response handling changes at all — only the receiver of `.get`/`.post`/`.put`/`.send` changes from the `http` package prefix to `_client`. Double-check each converted call site against the original file to confirm nothing else changed.

- [ ] **Step 4: Fix `ShoppingViewModel`'s two `fetchProducts` call sites for the new `ok` field**

`fetchProducts`'s return record gained an `ok` field — `lib/features/shopping/presentation/viewmodels/shopping_viewmodel.dart`'s `loadProducts` and `loadMoreProducts` destructure this record but don't yet read `ok`. This is fixed in Task 4 (next), not here — Task 3 only changes the service. Do not modify `shopping_viewmodel.dart` in this task; it will not compile between Step 3 and Task 4 starting, which is fine since these are consecutive tasks in the same session.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/services/shopping_service_test.dart`
Expected: PASS (12 tests). (`flutter analyze` will show pre-existing errors in `shopping_viewmodel.dart` referencing the old 2-field record shape until Task 4 — expected and resolved by the very next task.)

- [ ] **Step 6: Commit**

```bash
git add lib/services/shopping_service.dart test/services/shopping_service_test.dart
git commit -m "feat(products): add injectable client, ok-flagged reads, trending/recommended/wishlist to ShoppingService"
```

---

### Task 4: `ShoppingViewModel` — fix dead try/catch, add trending/recommended/wishlist state

**Files:**
- Modify: `lib/features/shopping/presentation/viewmodels/shopping_viewmodel.dart`
- Test: `test/features/shopping/shopping_viewmodel_products_test.dart`

**Interfaces:**
- Consumes: `ShoppingService` (Task 3).
- Produces: `trendingProducts`/`trendingLoading`/`trendingError`, `recommendedProducts`/`recommendedLoading`/`recommendedError`, `wishlistProductIds`, `loadTrendingProducts()`, `loadRecommendedProducts(String userId)`, `loadWishlist(String userId)`, `toggleWishlist(String userId, String productId)`, `isWishlisted(String productId)`. Consumed by Task 6 (Explore section widget) and Task 5 (`ProductCard`'s favourite button, wired at the Explore call site).

- [ ] **Step 1: Write the failing tests**

Create `test/features/shopping/shopping_viewmodel_products_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/models/shopping/banner.dart' as shopping_banner;
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/services/shopping_service.dart';

Product _product(String id, {String category = 'General'}) {
  return Product(productId: id, name: 'Product $id', price: 10.0, category: category);
}

class FakeShoppingService implements ShoppingService {
  bool trendingOk = true;
  bool recommendedOk = true;
  List<Product> trendingResult = [_product('t1')];
  List<Product> recommendedResult = [_product('r1')];
  List<Product> wishlistResult = [];
  bool failAddToWishlist = false;
  bool failRemoveFromWishlist = false;

  @override
  Future<({List<Product> products, int totalPages, bool ok})> fetchTrendingProducts(
      {int page = 1, int limit = 10}) async {
    if (!trendingOk) return (products: <Product>[], totalPages: 0, ok: false);
    return (products: trendingResult, totalPages: 1, ok: true);
  }

  @override
  Future<({List<Product> products, int totalPages, bool ok})> fetchRecommendedProducts(
      {required String userId, int page = 1, int limit = 10}) async {
    if (!recommendedOk) return (products: <Product>[], totalPages: 0, ok: false);
    return (products: recommendedResult, totalPages: 1, ok: true);
  }

  @override
  Future<List<Product>> fetchWishlist(String userId) async => wishlistResult;

  @override
  Future<void> addToWishlist(String userId, String productId) async {
    if (failAddToWishlist) throw Exception('failed to add');
  }

  @override
  Future<void> removeFromWishlist(String userId, String productId) async {
    if (failRemoveFromWishlist) throw Exception('failed to remove');
  }

  @override
  Future<({List<Product> products, int totalPages, bool ok})> fetchProducts(
      {int page = 1, int limit = 10, String? category, String? search}) async {
    return (products: <Product>[], totalPages: 1, ok: true);
  }

  @override
  Future<List<String>> fetchCategories() async => [];

  @override
  Future<List<shopping_banner.Banner>> fetchBanners() async => [];

  @override
  Product? getProduct(String productId) => null;

  @override
  Future<Map<String, dynamic>> fetchCart(String userId) async =>
      {'items': [], 'total': 0.0};

  @override
  Future<Map<String, dynamic>> addToCart(String userId, String productId,
      {int quantity = 1}) async => {'items': [], 'total': 0.0};

  @override
  Future<Map<String, dynamic>> updateCartQuantity(
      String userId, String productId, int quantity) async => {'items': [], 'total': 0.0};

  @override
  Future<Map<String, dynamic>> removeFromCart(String userId, String productId) async =>
      {'items': [], 'total': 0.0};

  @override
  Future<void> clearCart(String userId) async {}

  @override
  Future<Order?> placeOrder(String userId, String shippingAddress,
      {String? transactionId,
      String paymentStatus = 'pending',
      double discountAmount = 0.0,
      String? discountCode,
      required Map<String, dynamic> cartSnapshot}) async => null;

  @override
  Future<List<Order>> fetchOrders(String userId) async => [];

  @override
  Future<int> fetchWishlistCount(String userId) async => wishlistResult.length;

  @override
  Future<Map<String, dynamic>> validateVoucher(String code, double total) async => {};
}

void main() {
  group('loadTrendingProducts', () {
    test('populates trendingProducts on success', () async {
      final vm = ShoppingViewModel(FakeShoppingService());

      await vm.loadTrendingProducts();

      expect(vm.trendingProducts, hasLength(1));
      expect(vm.trendingLoading, false);
      expect(vm.trendingError, isNull);
    });

    test('sets trendingError (not just an empty list) on failure', () async {
      final fake = FakeShoppingService()..trendingOk = false;
      final vm = ShoppingViewModel(fake);

      await vm.loadTrendingProducts();

      expect(vm.trendingError, isNotNull);
      expect(vm.trendingProducts, isEmpty);
    });
  });

  group('loadRecommendedProducts', () {
    test('populates recommendedProducts on success', () async {
      final vm = ShoppingViewModel(FakeShoppingService());

      await vm.loadRecommendedProducts('user1');

      expect(vm.recommendedProducts, hasLength(1));
      expect(vm.recommendedError, isNull);
    });

    test('sets recommendedError on failure, independently of trending', () async {
      final fake = FakeShoppingService()..recommendedOk = false;
      final vm = ShoppingViewModel(fake);

      await vm.loadTrendingProducts();
      await vm.loadRecommendedProducts('user1');

      expect(vm.recommendedError, isNotNull);
      expect(vm.trendingError, isNull, reason: 'a recommended failure must not affect trending');
      expect(vm.trendingProducts, hasLength(1));
    });
  });

  group('wishlist', () {
    test('loadWishlist populates wishlistProductIds and isWishlisted reflects it', () async {
      final fake = FakeShoppingService()..wishlistResult = [_product('w1')];
      final vm = ShoppingViewModel(fake);

      await vm.loadWishlist('user1');

      expect(vm.isWishlisted('w1'), true);
      expect(vm.isWishlisted('other'), false);
    });

    test('toggleWishlist optimistically adds and keeps the change on success', () async {
      final vm = ShoppingViewModel(FakeShoppingService());

      await vm.toggleWishlist('user1', 'p1');

      expect(vm.isWishlisted('p1'), true);
    });

    test('toggleWishlist reverts the optimistic add on failure', () async {
      final fake = FakeShoppingService()..failAddToWishlist = true;
      final vm = ShoppingViewModel(fake);

      await vm.toggleWishlist('user1', 'p1');

      expect(vm.isWishlisted('p1'), false);
    });

    test('toggleWishlist removes an already-wishlisted product optimistically', () async {
      final fake = FakeShoppingService()..wishlistResult = [_product('w1')];
      final vm = ShoppingViewModel(fake);
      await vm.loadWishlist('user1');

      await vm.toggleWishlist('user1', 'w1');

      expect(vm.isWishlisted('w1'), false);
    });

    test('toggleWishlist reverts the optimistic removal on failure', () async {
      final fake = FakeShoppingService()
        ..wishlistResult = [_product('w1')]
        ..failRemoveFromWishlist = true;
      final vm = ShoppingViewModel(fake);
      await vm.loadWishlist('user1');

      await vm.toggleWishlist('user1', 'w1');

      expect(vm.isWishlisted('w1'), true);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/shopping/shopping_viewmodel_products_test.dart`
Expected: FAIL — none of the new state/methods exist yet, and `FakeShoppingService` won't satisfy the `ShoppingService` interface's new signature until Task 3's changes are also in place (they are, since this is the very next task).

- [ ] **Step 3: Fix the pre-existing dead try/catch and add the new state**

In `lib/features/shopping/presentation/viewmodels/shopping_viewmodel.dart`, make these changes:

Add these fields alongside the existing ones (near `_recentSearches`):

```dart
  List<Product> _trendingProducts = [];
  bool _trendingLoading = false;
  String? _trendingError;

  List<Product> _recommendedProducts = [];
  bool _recommendedLoading = false;
  String? _recommendedError;

  List<String> _wishlistProductIds = [];
```

Add these getters alongside the existing ones:

```dart
  List<Product> get trendingProducts => _trendingProducts;
  bool get trendingLoading => _trendingLoading;
  String? get trendingError => _trendingError;

  List<Product> get recommendedProducts => _recommendedProducts;
  bool get recommendedLoading => _recommendedLoading;
  String? get recommendedError => _recommendedError;

  List<String> get wishlistProductIds => _wishlistProductIds;
```

Replace the existing `loadProducts` method body's success/failure handling — this fixes the pre-existing dead try/catch (fetchProducts never throws, so the old `catch (e) { _setError(...) }` never ran):

```dart
  Future<void> loadProducts({String? category, String? search}) async {
    _setLoading(true);
    _setError(null);
    _page = 1;
    _totalPages = 1;

    await Future.wait([loadCategories(), loadBanners()]);

    final cat = category ?? _selectedCategory;
    final q = search ?? _searchQuery;

    final result = await _service.fetchProducts(
      page: 1,
      category: cat,
      search: q.isEmpty ? null : q,
    );

    if (result.ok) {
      _products = result.products;
      _totalPages = result.totalPages;
    } else {
      _setError('Failed to load products. Check your connection and try again.');
    }
    _setLoading(false);
  }
```

Replace `loadMoreProducts` the same way:

```dart
  Future<void> loadMoreProducts() async {
    if (_isLoading || _isMoreLoading || _page >= _totalPages) return;
    _setMoreLoading(true);
    final nextPage = _page + 1;
    final result = await _service.fetchProducts(
      page: nextPage,
      category: _selectedCategory,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    if (result.ok) {
      _page = nextPage;
      _products.addAll(result.products);
    } else {
      _setError('Failed to load more products.');
    }
    _setMoreLoading(false);
  }
```

(`_setLoading`/`_setMoreLoading`/`_setError` already call `notifyListeners()` internally — no change needed there.)

Add these new methods, near `loadProducts`/`loadMoreProducts`:

```dart
  Future<void> loadTrendingProducts() async {
    _trendingLoading = true;
    _trendingError = null;
    notifyListeners();

    final result = await _service.fetchTrendingProducts();
    if (result.ok) {
      _trendingProducts = result.products;
    } else {
      _trendingError = 'Failed to load trending products. Check your connection and try again.';
    }
    _trendingLoading = false;
    notifyListeners();
  }

  Future<void> loadRecommendedProducts(String userId) async {
    _recommendedLoading = true;
    _recommendedError = null;
    notifyListeners();

    final result = await _service.fetchRecommendedProducts(userId: userId);
    if (result.ok) {
      _recommendedProducts = result.products;
    } else {
      _recommendedError =
          'Failed to load recommended products. Check your connection and try again.';
    }
    _recommendedLoading = false;
    notifyListeners();
  }
```

Add wishlist methods, in a new section near the end of the class (before the closing brace):

```dart
  // ── Wishlist (favourite button) ───────────────────────────────────────────

  Future<void> loadWishlist(String userId) async {
    try {
      final products = await _service.fetchWishlist(userId);
      _wishlistProductIds = products.map((p) => p.productId).toList();
      notifyListeners();
    } catch (_) {
      // Silent -- the favourite button simply won't show as filled; not
      // worth a dedicated error state for a background wishlist-state sync.
    }
  }

  bool isWishlisted(String productId) => _wishlistProductIds.contains(productId);

  Future<void> toggleWishlist(String userId, String productId) async {
    final wasWishlisted = isWishlisted(productId);
    _wishlistProductIds = wasWishlisted
        ? _wishlistProductIds.where((id) => id != productId).toList()
        : [..._wishlistProductIds, productId];
    notifyListeners();

    try {
      if (wasWishlisted) {
        await _service.removeFromWishlist(userId, productId);
      } else {
        await _service.addToWishlist(userId, productId);
      }
    } catch (e) {
      _wishlistProductIds = wasWishlisted
          ? [..._wishlistProductIds, productId]
          : _wishlistProductIds.where((id) => id != productId).toList();
      notifyListeners();
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/shopping/shopping_viewmodel_products_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Run the full Flutter test suite excluding the known unrelated live-network test to confirm no regressions**

Run: `flutter test $(find test -name "*.dart" ! -name "grpc_balance_test.dart")`
Expected: PASS, except the pre-existing, already-accepted `explore_tab_test.dart` failures (`ProviderNotFoundException` — unrelated to this change, documented in an earlier plan).

- [ ] **Step 6: Commit**

```bash
git add lib/features/shopping/presentation/viewmodels/shopping_viewmodel.dart test/features/shopping/shopping_viewmodel_products_test.dart
git commit -m "fix(products): resolve dead try/catch in loadProducts/loadMoreProducts, add trending/recommended/wishlist state"
```

---

### Task 5: `ProductCard` — rating, verified badge, delivery indicator, discount badge, store name, real favourite wiring

**Files:**
- Modify: `lib/features/shopping/presentation/views/widgets/product_card.dart`
- Test: `test/features/shopping/product_card_test.dart`

**Interfaces:**
- Consumes: `Product` (Task 2, new fields).
- Produces: `ProductCard`'s existing constructor gains one new parameter: `required bool isFavorited` (the caller now controls the favourite icon's filled/outline state — previously it was always outline/unfilled since nothing wired it). All other existing parameters (`product`, `onTap`, `onAddToCart`, `onFavorite`, `viewMode`) are unchanged. Consumed by Task 6 (Explore section widget) and by the existing Shopping-tab grid call site (`product_grid.dart`), which must be updated to pass `isFavorited: false` (it has no wishlist state wired yet — out of scope for this plan per the spec's non-goals — so it keeps today's always-unfilled behavior unchanged).

- [ ] **Step 1: Write the failing tests**

Create `test/features/shopping/product_card_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/shopping/product_card_test.dart`
Expected: FAIL — `ProductCard` has no `isFavorited` parameter and none of the new rows exist yet.

- [ ] **Step 3: Extend `ProductCard`**

Replace the full contents of `lib/features/shopping/presentation/views/widgets/product_card.dart` with:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final bool isFavorited;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onFavorite;
  final ProductViewMode viewMode;

  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorited,
    this.onTap,
    this.onAddToCart,
    this.onFavorite,
    this.viewMode = ProductViewMode.medium,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = viewMode == ProductViewMode.small || viewMode == ProductViewMode.extraSmall;
    final hasDiscount = product.discountPrice != null && product.discountPrice! < product.price;
    final discountPercent = hasDiscount
        ? (((product.price - product.discountPrice!) / product.price) * 100).round()
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: WunzaColors.surface,
          borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: isSmall ? 4 : 8,
              offset: Offset(0, isSmall ? 1 : 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(isSmall ? 8 : 12)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl.isNotEmpty
                          ? product.imageUrl
                          : 'https://via.placeholder.com/150',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error, size: 16),
                      ),
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: WunzaColors.padGradientEnd,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (!isSmall) // Hide favorite in small mode to save space
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorited ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFavorited ? WunzaColors.padGradientEnd : WunzaColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info Section
            Padding(
              padding: EdgeInsets.all(isSmall ? 4.0 : 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isSmall)
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  if (!isSmall && product.storeName != null && product.storeName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.storeName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: WunzaColors.textSecondary,
                                ),
                          ),
                        ),
                        if (product.verifiedSeller) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: WunzaColors.primary),
                        ],
                      ],
                    ),
                  ],
                  if (!isSmall && product.reviewCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${product.averageRating.toStringAsFixed(1)} (${product.reviewCount})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: WunzaColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ],
                  if (!isSmall && product.deliveryAvailable) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 14, color: WunzaColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Delivery',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: WunzaColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ],
                  if (!isSmall) const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '\$${(hasDiscount ? product.discountPrice! : product.price).toStringAsFixed(isSmall ? 0 : 2)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSmall ? 12 : 18,
                                      ),
                                ),
                                if (!isSmall) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    'USD',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: WunzaColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                            if (!isSmall && hasDiscount) ...[
                              const SizedBox(width: 6),
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: WunzaColors.textSecondary,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onAddToCart,
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 24,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Fix the existing call site**

`lib/features/shopping/presentation/views/widgets/product_grid.dart` constructs `ProductCard` without the now-required `isFavorited` parameter. In its `itemBuilder`, change:

```dart
        return ProductCard(
          product: product,
          viewMode: viewMode, // Pass viewMode
          onTap: () => onProductTap(product),
          onAddToCart: () => onAddToCart(product),
          onFavorite: () {
            // TODO: Implement favorite
          },
        );
```

to:

```dart
        return ProductCard(
          product: product,
          isFavorited: false, // Shopping-tab grid has no wishlist state wired yet -- out of scope for this plan
          viewMode: viewMode, // Pass viewMode
          onTap: () => onProductTap(product),
          onAddToCart: () => onAddToCart(product),
          onFavorite: () {
            // TODO: Implement favorite
          },
        );
```

This is a one-line addition preserving the grid's exact existing (always-unfilled, non-functional) favourite behavior — this plan does not wire wishlist state into the Shopping-tab grid, only into the new Explore section (Task 6).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/shopping/product_card_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 6: Run `flutter analyze` to confirm the call-site fix compiles cleanly**

Run: `flutter analyze lib/features/shopping/presentation/views/widgets/product_card.dart lib/features/shopping/presentation/views/widgets/product_grid.dart`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/features/shopping/presentation/views/widgets/product_card.dart lib/features/shopping/presentation/views/widgets/product_grid.dart test/features/shopping/product_card_test.dart
git commit -m "feat(products): add rating, verified badge, delivery indicator, discount badge, and real favourite state to ProductCard"
```

---

### Task 6: Explore — real product sections (shimmer/error/empty/success) replacing the placeholder rows

**Files:**
- Create: `lib/features/home/presentation/widgets/explore_product_section.dart`
- Modify: `lib/features/home/presentation/widgets/explore_tab.dart`
- Test: `test/features/home/explore_product_section_test.dart`

**Interfaces:**
- Consumes: `ShoppingViewModel` (Task 4), `ProductCard` (Task 5), `ShimmerWidget` (`lib/shared/widgets/shimmer_widget.dart`, pre-existing).
- Produces: `ExploreProductSection({title, subtitle, products, isLoading, error, onRetry, emptyTitle, emptyMessage, onEmptyAction, emptyActionLabel, currentUserId, isWishlisted, onFavoriteTap, onProductTap, onAddToCart})`. This is the final integration point for this plan — no further tasks consume it.

- [ ] **Step 1: Write the failing tests**

Create `test/features/home/explore_product_section_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/home/explore_product_section_test.dart`
Expected: FAIL — `explore_product_section.dart` doesn't exist yet.

- [ ] **Step 3: Create `explore_product_section.dart`**

Create `lib/features/home/presentation/widgets/explore_product_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/widgets/product_card.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
import 'package:mvvm_sip_demo/shared/widgets/shimmer_widget.dart';

/// A titled, horizontally-scrolling row of real [Product] cards, with real
/// loading (shimmer)/success/empty/error states -- the real-data counterpart
/// to the static [DiscoverySection] used by Explore's other, still-placeholder
/// rows (Businesses, Deals).
class ExploreProductSection extends StatelessWidget {
  const ExploreProductSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyActionLabel,
    required this.onEmptyAction,
    required this.currentUserId,
    required this.isWishlisted,
    required this.onFavoriteTap,
    required this.onProductTap,
    required this.onAddToCart,
  });

  final String title;
  final String subtitle;
  final List<Product> products;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyActionLabel;
  final VoidCallback onEmptyAction;
  final String currentUserId;
  final bool Function(String productId) isWishlisted;
  final ValueChanged<Product> onFavoriteTap;
  final ValueChanged<Product> onProductTap;
  final ValueChanged<Product> onAddToCart;

  static const double _rowHeight = 240;
  static const double _cardWidth = 160;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        key: const Key('explore-product-section-shimmer'),
        height: _rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => SizedBox(
            width: _cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(child: ShimmerWidget.rectangular(height: double.infinity)),
                SizedBox(height: 8),
                ShimmerWidget.rectangular(height: 14),
                SizedBox(height: 6),
                ShimmerWidget.rectangular(height: 14, width: 80),
              ],
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(emptyTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(emptyMessage, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(onPressed: onEmptyAction, child: Text(emptyActionLabel)),
          ],
        ),
      );
    }

    return SizedBox(
      height: _rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final product = products[i];
          return SizedBox(
            width: _cardWidth,
            child: ProductCard(
              product: product,
              isFavorited: isWishlisted(product.productId),
              onTap: () => onProductTap(product),
              onAddToCart: () => onAddToCart(product),
              onFavorite: () => onFavoriteTap(product),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/home/explore_product_section_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Wire into `explore_tab.dart`**

In `lib/features/home/presentation/widgets/explore_tab.dart`:

Add these four imports alongside the existing ones:

```dart
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_product_section.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/models/shopping/product.dart';
```

In `_ExploreTabState.initState`, kick off the trending load immediately (it needs no user context) by adding this line right after `_scrollController.addListener(_onScroll);` and before the existing `WidgetsBinding.instance.addPostFrameCallback(...)` block:

```dart
    context.read<ShoppingViewModel>().loadTrendingProducts();
```

Inside the existing `addPostFrameCallback` block, right after the existing `context.read<PostsViewModel>().loadFeed(_userId);` line, add:

```dart
      final shoppingVM = context.read<ShoppingViewModel>();
      shoppingVM.loadRecommendedProducts(_userId);
      shoppingVM.loadWishlist(_userId);
```

Add a helper method to the state class, alongside the other `_open...` helpers:

```dart
  void _openProductDetails(Product product) {
    Navigator.pushNamed(context, Routes.productDetails, arguments: product);
  }

  void _addProductToCart(Product product) {
    context.read<ShoppingViewModel>().addToCart(_userId, product.productId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} added to cart')),
    );
  }
```

In `build`, add a `final shoppingVM = context.watch<ShoppingViewModel>();` line right after the existing `final postsVM = context.watch<PostsViewModel>();` line.

Replace the two existing `DiscoverySection` instances for `'Trending Now'` and `'Recommended Products'`:

```dart
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
```

with:

```dart
                      ExploreProductSection(
                        title: 'Trending Now',
                        subtitle: "What's popular right now",
                        products: shoppingVM.trendingProducts,
                        isLoading: shoppingVM.trendingLoading,
                        error: shoppingVM.trendingError,
                        onRetry: () => shoppingVM.loadTrendingProducts(),
                        emptyTitle: 'No Trending Products Yet',
                        emptyMessage: 'Check back later. New products are added every day.',
                        emptyActionLabel: 'Browse Categories',
                        onEmptyAction: _openSearchSheet,
                        currentUserId: _userId,
                        isWishlisted: shoppingVM.isWishlisted,
                        onFavoriteTap: (p) => shoppingVM.toggleWishlist(_userId, p.productId),
                        onProductTap: _openProductDetails,
                        onAddToCart: _addProductToCart,
                      ),
                      ExploreProductSection(
                        title: 'Recommended Products',
                        subtitle: 'Picked for you',
                        products: shoppingVM.recommendedProducts,
                        isLoading: shoppingVM.recommendedLoading,
                        error: shoppingVM.recommendedError,
                        onRetry: () => shoppingVM.loadRecommendedProducts(_userId),
                        emptyTitle: 'No Recommendations Yet',
                        emptyMessage: 'Browse a few products and we\'ll start tailoring picks for you.',
                        emptyActionLabel: 'Browse Categories',
                        onEmptyAction: _openSearchSheet,
                        currentUserId: _userId,
                        isWishlisted: shoppingVM.isWishlisted,
                        onFavoriteTap: (p) => shoppingVM.toggleWishlist(_userId, p.productId),
                        onProductTap: _openProductDetails,
                        onAddToCart: _addProductToCart,
                      ),
```

The other two `DiscoverySection`s ("Popular Businesses", "Deals & Promotions") are untouched. The now-unused `trendingItems`/`recommendedItems` imports from `explore_models.dart` are no longer referenced by these two replaced sections, but `explore_models.dart` itself is untouched (`businessItems`/`dealItems`/`exploreCategories`/etc. are still used by the untouched sections and the search sheet) — do not delete anything from `explore_models.dart` in this task.

- [ ] **Step 6: Confirm the existing Explore tests' failure signature is unchanged**

Run: `flutter test test/features/home/explore_tab_test.dart`
Expected: still fails with `ProviderNotFoundException` (now for both `PostsViewModel` and `ShoppingViewModel` — `ShoppingViewModel` was already a dependency of this widget indirectly is not true before this change, so this task adds it as a new required ancestor). This is the same accepted, documented trade-off from the Posts feature's Task 6, not a new regression to fix.

Run: `flutter analyze lib/features/home/presentation/widgets/explore_tab.dart lib/features/home/presentation/widgets/explore_product_section.dart`
Expected: "No issues found!"

- [ ] **Step 7: Run the full Flutter test suite excluding the known unrelated live-network test**

Run: `flutter test $(find test -name "*.dart" ! -name "grpc_balance_test.dart")`
Expected: PASS except the pre-existing, already-accepted `explore_tab_test.dart` failures.

- [ ] **Step 8: Commit**

```bash
git add lib/features/home/presentation/widgets/explore_product_section.dart lib/features/home/presentation/widgets/explore_tab.dart test/features/home/explore_product_section_test.dart
git commit -m "feat(explore): replace Trending/Recommended placeholder cards with real ProductCard-backed sections"
```
