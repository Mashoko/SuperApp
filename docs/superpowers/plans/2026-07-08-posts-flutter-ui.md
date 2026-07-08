# Posts Flutter UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Flutter client for the just-shipped Posts backend API: a data layer (`Post`/`PostsService`/`PostsViewModel`), a 4-choice composer (photo/video/text/audio), feed cards with optimistic like toggling and native share, and wire it all into `ExploreTab` below the existing discovery sections as an infinite-scrolling feed.

**Architecture:** `PostsService` matches `ShoppingService`'s existing per-endpoint raw-`http` style (one deliberate deviation: an injectable `http.Client` for testability, since `http`-based services in this codebase have no prior test coverage to preserve). `PostsViewModel` matches `ShoppingViewModel`'s `ChangeNotifier` conventions. Composer flows and feed cards are self-contained widgets wired together only in the final integration task, which also registers the new service/viewmodel in this app's existing `get_it` + `Provider` DI setup.

**Tech Stack:** Flutter, `provider` (already used), new packages: `file_picker`, `share_plus`, `video_player`.

## Global Constraints

- `PostsService`'s base URL, error-handling style (silent-fallback for reads, throw-on-failure for user-initiated writes), and one-method-per-endpoint structure must match `lib/services/shopping_service.dart` exactly, except for the injectable-`http.Client` deviation noted above.
- `PostsViewModel` must extend `ChangeNotifier` and follow `ShoppingViewModel`'s loading/error field conventions.
- No comment-thread UI — the comment icon opens the existing `MaintenanceScreen` placeholder.
- Share uses `share_plus`'s native share sheet — no backend call, no persisted count.
- Video/audio `durationSeconds` is never sent at post-creation time; video duration is only ever shown live during playback via the player's own metadata.
- Audio composer picks an existing file (`file_picker`) — no recording.
- No dedicated single-post detail screen — all cards are fully inline.
- `authorUserId` is the `OtpAuthService`-stored `username` (same convention as cart/wishlist/orders); `authorName` is `AccountSummaryViewModel.alias`, resolved fresh at compose time (not cached), falling back to `'You'` if unset.
- Feed gets real loading/error/empty states; the rest of `ExploreTab` (search bar, categories, banner, 4 discovery sections) is untouched.

---

### Task 1: `Post` model + `PostsService`

**Files:**
- Create: `lib/models/post.dart`
- Create: `lib/services/posts_service.dart`
- Test: `test/models/post_test.dart`
- Test: `test/services/posts_service_test.dart`

**Interfaces:**
- Produces: `enum PostType { photo, video, text, audio }`; `class Post` with fields `id`, `type`, `caption`, `mediaUrl`, `audioTitle`, `authorUserId`, `authorName`, `likedBy` (`List<String>`), `commentCount`, `createdAt`, method `isLikedBy(String userId)`, factory `Post.fromJson(Map<String, dynamic>)`. `class FeedPage { List<Post> posts; int totalPages; int currentPage; }`. `class LikeResult { bool liked; int likeCount; }`. `class PostsService` with constructor `PostsService({http.Client? client})` and methods `fetchFeed({required int page, int limit = 10}) → Future<FeedPage>`, `createPost({required PostType type, String? caption, required String authorUserId, required String authorName, String? audioTitle, File? mediaFile}) → Future<Post>` (throws on failure), `toggleLike({required String postId, required String userId}) → Future<LikeResult>` (throws on failure), `deletePost({required String postId, required String authorUserId}) → Future<void>` (throws on failure). Consumed by Task 2.

- [ ] **Step 1: Write the failing test for `Post`**

Create `test/models/post_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/models/post.dart';

void main() {
  test('Post.fromJson parses a full JSON post correctly', () {
    final json = {
      '_id': 'p1',
      'type': 'photo',
      'caption': 'Nice view',
      'mediaUrl': '/uploads/abc.png',
      'audioTitle': null,
      'authorUserId': 'user1',
      'authorName': 'Alice',
      'likedBy': ['user2', 'user3'],
      'commentCount': 4,
      'createdAt': '2026-07-08T10:00:00.000Z',
    };

    final post = Post.fromJson(json);

    expect(post.id, 'p1');
    expect(post.type, PostType.photo);
    expect(post.caption, 'Nice view');
    expect(post.mediaUrl, '/uploads/abc.png');
    expect(post.authorUserId, 'user1');
    expect(post.authorName, 'Alice');
    expect(post.likedBy, ['user2', 'user3']);
    expect(post.commentCount, 4);
    expect(post.createdAt, DateTime.parse('2026-07-08T10:00:00.000Z'));
  });

  test('isLikedBy reflects membership in likedBy', () {
    final post = Post(
      id: 'p1',
      type: PostType.text,
      authorUserId: 'user1',
      authorName: 'Alice',
      likedBy: const ['user2'],
      commentCount: 0,
      createdAt: DateTime(2026, 7, 8),
    );

    expect(post.isLikedBy('user2'), true);
    expect(post.isLikedBy('user3'), false);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/post_test.dart`
Expected: FAIL — `package:mvvm_sip_demo/models/post.dart` does not exist.

- [ ] **Step 3: Create the `Post` model**

Create `lib/models/post.dart`:

```dart
enum PostType { photo, video, text, audio }

class Post {
  const Post({
    required this.id,
    required this.type,
    this.caption,
    this.mediaUrl,
    this.audioTitle,
    required this.authorUserId,
    required this.authorName,
    required this.likedBy,
    required this.commentCount,
    required this.createdAt,
  });

  final String id;
  final PostType type;
  final String? caption;
  final String? mediaUrl;
  final String? audioTitle;
  final String authorUserId;
  final String authorName;
  final List<String> likedBy;
  final int commentCount;
  final DateTime createdAt;

  bool isLikedBy(String userId) => likedBy.contains(userId);

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] as String,
      type: PostType.values.byName(json['type'] as String),
      caption: json['caption'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      audioTitle: json['audioTitle'] as String?,
      authorUserId: json['authorUserId'] as String,
      authorName: json['authorName'] as String,
      likedBy: (json['likedBy'] as List).map((e) => e as String).toList(),
      commentCount: json['commentCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/post_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Write the failing tests for `PostsService`**

Create `test/services/posts_service_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mvvm_sip_demo/models/post.dart';
import 'package:mvvm_sip_demo/services/posts_service.dart';

Map<String, dynamic> _postJson({String id = 'p1'}) => {
      '_id': id,
      'type': 'text',
      'caption': 'hi',
      'authorUserId': 'user1',
      'authorName': 'Alice',
      'likedBy': <String>[],
      'commentCount': 0,
      'createdAt': '2026-07-08T10:00:00.000Z',
    };

void main() {
  group('fetchFeed', () {
    test('parses a successful paginated response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/posts');
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['limit'], '10');
        return http.Response(
          json.encode({
            'posts': [_postJson()],
            'totalPages': 3,
            'currentPage': 1,
            'totalPosts': 25,
          }),
          200,
        );
      });

      final service = PostsService(client: mockClient);
      final page = await service.fetchFeed(page: 1);

      expect(page.posts, hasLength(1));
      expect(page.posts.first.id, 'p1');
      expect(page.totalPages, 3);
      expect(page.currentPage, 1);
    });

    test('returns an empty page on a non-200 response', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = PostsService(client: mockClient);

      final page = await service.fetchFeed(page: 1);

      expect(page.posts, isEmpty);
    });
  });

  group('createPost', () {
    test('sends multipart fields and parses the created post', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/posts');
        return http.Response(json.encode(_postJson(id: 'p2')), 201);
      });

      final service = PostsService(client: mockClient);
      final post = await service.createPost(
        type: PostType.text,
        caption: 'hello',
        authorUserId: 'user1',
        authorName: 'Alice',
      );

      expect(post.id, 'p2');
    });

    test('throws on a non-201 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({'message': 'type is required'}), 400);
      });
      final service = PostsService(client: mockClient);

      expect(
        () => service.createPost(
          type: PostType.text,
          authorUserId: 'user1',
          authorName: 'Alice',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('toggleLike', () {
    test('parses liked/likeCount from a successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/posts/p1/like');
        return http.Response(json.encode({'liked': true, 'likeCount': 5}), 200);
      });
      final service = PostsService(client: mockClient);

      final result = await service.toggleLike(postId: 'p1', userId: 'user1');

      expect(result.liked, true);
      expect(result.likeCount, 5);
    });

    test('throws on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({'message': 'Post not found'}), 404);
      });
      final service = PostsService(client: mockClient);

      expect(
        () => service.toggleLike(postId: 'missing', userId: 'user1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('deletePost', () {
    test('completes without throwing on a successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/posts/p1');
        return http.Response(json.encode({'message': 'Post deleted'}), 200);
      });
      final service = PostsService(client: mockClient);

      await expectLater(
        service.deletePost(postId: 'p1', authorUserId: 'user1'),
        completes,
      );
    });

    test('throws on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
            json.encode({'message': 'Only the author can delete this post'}), 403);
      });
      final service = PostsService(client: mockClient);

      expect(
        () => service.deletePost(postId: 'p1', authorUserId: 'user2'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `flutter test test/services/posts_service_test.dart`
Expected: FAIL — `package:mvvm_sip_demo/services/posts_service.dart` does not exist.

- [ ] **Step 7: Create `PostsService`**

Create `lib/services/posts_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mvvm_sip_demo/models/post.dart';

class FeedPage {
  const FeedPage({
    required this.posts,
    required this.totalPages,
    required this.currentPage,
  });

  final List<Post> posts;
  final int totalPages;
  final int currentPage;
}

class LikeResult {
  const LikeResult({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;
}

/// Matches ShoppingService's per-endpoint raw-http style, with one
/// deliberate deviation: an injectable http.Client (defaulting to a real
/// one) so this service can be unit-tested with MockClient. No http-based
/// service in this codebase has prior test coverage to preserve, so this
/// is a net-new testability improvement, not a departure from a tested
/// convention.
class PostsService {
  PostsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base = 'https://superapp-diht.onrender.com/api';

  Future<FeedPage> fetchFeed({required int page, int limit = 10}) async {
    try {
      final response =
          await _client.get(Uri.parse('$_base/posts?page=$page&limit=$limit'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final posts = (data['posts'] as List)
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();
        return FeedPage(
          posts: posts,
          totalPages: data['totalPages'] as int,
          currentPage: data['currentPage'] as int,
        );
      }
      return FeedPage(posts: const [], totalPages: 1, currentPage: page);
    } catch (e) {
      return FeedPage(posts: const [], totalPages: 1, currentPage: page);
    }
  }

  Future<Post> createPost({
    required PostType type,
    String? caption,
    required String authorUserId,
    required String authorName,
    String? audioTitle,
    File? mediaFile,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/posts'))
        ..fields['type'] = type.name
        ..fields['authorUserId'] = authorUserId
        ..fields['authorName'] = authorName;
      if (caption != null) request.fields['caption'] = caption;
      if (audioTitle != null) request.fields['audioTitle'] = audioTitle;
      if (mediaFile != null) {
        request.files.add(await http.MultipartFile.fromPath('media', mediaFile.path));
      }

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return Post.fromJson(json.decode(response.body) as Map<String, dynamic>);
      }
      final error = json.decode(response.body) as Map<String, dynamic>;
      throw Exception(error['message'] ?? 'Failed to create post');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<LikeResult> toggleLike({required String postId, required String userId}) async {
    try {
      final response = await _client.post(
        Uri.parse('$_base/posts/$postId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return LikeResult(liked: data['liked'] as bool, likeCount: data['likeCount'] as int);
      }
      final error = json.decode(response.body) as Map<String, dynamic>;
      throw Exception(error['message'] ?? 'Failed to update like');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deletePost({required String postId, required String authorUserId}) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_base/posts/$postId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'authorUserId': authorUserId}),
      );
      if (response.statusCode != 200) {
        final error = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(error['message'] ?? 'Failed to delete post');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/models/post_test.dart test/services/posts_service_test.dart`
Expected: PASS (10 tests: 2 + 8).

- [ ] **Step 9: Commit**

```bash
git add lib/models/post.dart lib/services/posts_service.dart test/models/post_test.dart test/services/posts_service_test.dart
git commit -m "feat(posts): add Post model and PostsService HTTP client"
```

---

### Task 2: `PostsViewModel`

**Files:**
- Create: `lib/features/home/presentation/viewmodels/posts_viewmodel.dart`
- Test: `test/features/home/posts_viewmodel_test.dart`

**Interfaces:**
- Consumes: `Post`, `PostType`, `FeedPage`, `LikeResult`, `PostsService` (Task 1).
- Produces: `class PostsViewModel extends ChangeNotifier` with constructor `PostsViewModel(PostsService service)`, getters `posts` (`List<Post>`), `isLoading`, `isLoadingMore`, `error` (`String?`), `hasMore`, and methods `loadFeed(String userId)`, `loadMore(String userId)`, `toggleLike(String postId, String userId)`, `createPost({required PostType type, String? caption, required String authorUserId, required String authorName, String? audioTitle, File? mediaFile})`, `deletePost(String postId, String authorUserId)`. Consumed by Tasks 5 and 6.

- [ ] **Step 1: Write the failing tests**

Create `test/features/home/posts_viewmodel_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart';
import 'package:mvvm_sip_demo/models/post.dart';
import 'package:mvvm_sip_demo/services/posts_service.dart';

Post _post(String id, {List<String> likedBy = const []}) {
  return Post(
    id: id,
    type: PostType.text,
    caption: 'caption $id',
    authorUserId: 'author1',
    authorName: 'Alice',
    likedBy: likedBy,
    commentCount: 0,
    createdAt: DateTime(2026, 7, 8),
  );
}

class FakePostsService implements PostsService {
  List<Post> feedPage1 = [_post('p1'), _post('p2')];
  List<Post> feedPage2 = [_post('p3')];
  int totalPages = 2;
  bool failFetch = false;
  bool failLike = false;
  bool failCreate = false;
  bool failDelete = false;
  Post? createdPost;
  // When set, toggleLike waits on this instead of returning immediately —
  // lets a test observe the ViewModel's state *before* the network call
  // resolves, to verify the optimistic update actually happens synchronously
  // rather than only after the awaited call completes.
  Completer<LikeResult>? likeCompleter;

  @override
  Future<FeedPage> fetchFeed({required int page, int limit = 10}) async {
    if (failFetch) throw Exception('network error');
    if (page == 1) {
      return FeedPage(posts: feedPage1, totalPages: totalPages, currentPage: 1);
    }
    return FeedPage(posts: feedPage2, totalPages: totalPages, currentPage: 2);
  }

  @override
  Future<Post> createPost({
    required PostType type,
    String? caption,
    required String authorUserId,
    required String authorName,
    String? audioTitle,
    File? mediaFile,
  }) async {
    if (failCreate) throw Exception('upload failed');
    return createdPost ?? _post('new-post');
  }

  @override
  Future<LikeResult> toggleLike({required String postId, required String userId}) async {
    if (failLike) throw Exception('like failed');
    if (likeCompleter != null) return likeCompleter!.future;
    return const LikeResult(liked: true, likeCount: 1);
  }

  @override
  Future<void> deletePost({required String postId, required String authorUserId}) async {
    if (failDelete) throw Exception('delete failed');
  }
}

void main() {
  group('loadFeed', () {
    test('populates posts and pagination state on success', () async {
      final vm = PostsViewModel(FakePostsService());

      await vm.loadFeed('user1');

      expect(vm.posts, hasLength(2));
      expect(vm.posts.first.id, 'p1');
      expect(vm.isLoading, false);
      expect(vm.error, isNull);
      expect(vm.hasMore, true);
    });

    test('sets error on failure', () async {
      final fake = FakePostsService()..failFetch = true;
      final vm = PostsViewModel(fake);

      await vm.loadFeed('user1');

      expect(vm.error, isNotNull);
      expect(vm.posts, isEmpty);
    });
  });

  group('loadMore', () {
    test('appends the next page and updates hasMore', () async {
      final vm = PostsViewModel(FakePostsService());
      await vm.loadFeed('user1');

      await vm.loadMore('user1');

      expect(vm.posts, hasLength(3));
      expect(vm.posts.last.id, 'p3');
      expect(vm.hasMore, false);
    });

    test('is a no-op when hasMore is false', () async {
      final fake = FakePostsService()..totalPages = 1;
      final vm = PostsViewModel(fake);
      await vm.loadFeed('user1');

      await vm.loadMore('user1');

      expect(vm.posts, hasLength(2));
    });
  });

  group('toggleLike', () {
    test('optimistically updates and keeps the change on success', () async {
      final vm = PostsViewModel(FakePostsService());
      await vm.loadFeed('user1');

      await vm.toggleLike('p1', 'user1');

      expect(vm.posts.firstWhere((p) => p.id == 'p1').isLikedBy('user1'), true);
    });

    test('reverts the optimistic update on failure', () async {
      final fake = FakePostsService()..failLike = true;
      final vm = PostsViewModel(fake);
      await vm.loadFeed('user1');

      await vm.toggleLike('p1', 'user1');

      expect(vm.posts.firstWhere((p) => p.id == 'p1').isLikedBy('user1'), false);
    });

    test('applies the optimistic update synchronously, before the network call resolves',
        () async {
      final fake = FakePostsService();
      final completer = Completer<LikeResult>();
      fake.likeCompleter = completer;
      final vm = PostsViewModel(fake);
      await vm.loadFeed('user1');

      final pending = vm.toggleLike('p1', 'user1'); // deliberately not awaited yet

      // The optimistic update must already be visible even though the fake
      // service's toggleLike call hasn't resolved — this is the actual
      // property this task exists to deliver (a like that feels instant).
      expect(vm.posts.firstWhere((p) => p.id == 'p1').isLikedBy('user1'), true);

      completer.complete(const LikeResult(liked: true, likeCount: 1));
      await pending;

      expect(vm.posts.firstWhere((p) => p.id == 'p1').isLikedBy('user1'), true);
    });
  });

  group('createPost', () {
    test('prepends the created post to the feed', () async {
      final fake = FakePostsService()..createdPost = _post('brand-new');
      final vm = PostsViewModel(fake);
      await vm.loadFeed('user1');

      await vm.createPost(
        type: PostType.text,
        caption: 'hello',
        authorUserId: 'user1',
        authorName: 'Alice',
      );

      expect(vm.posts.first.id, 'brand-new');
      expect(vm.posts, hasLength(3));
    });

    test('rethrows on failure without mutating posts', () async {
      final fake = FakePostsService()..failCreate = true;
      final vm = PostsViewModel(fake);
      await vm.loadFeed('user1');

      expect(
        () => vm.createPost(
          type: PostType.text,
          authorUserId: 'user1',
          authorName: 'Alice',
        ),
        throwsA(isA<Exception>()),
      );
      expect(vm.posts, hasLength(2));
    });
  });

  group('deletePost', () {
    test('removes the post from the feed on success', () async {
      final vm = PostsViewModel(FakePostsService());
      await vm.loadFeed('user1');

      await vm.deletePost('p1', 'user1');

      expect(vm.posts.any((p) => p.id == 'p1'), false);
      expect(vm.posts, hasLength(1));
    });

    test('rethrows on failure without mutating posts', () async {
      final fake = FakePostsService()..failDelete = true;
      final vm = PostsViewModel(fake);
      await vm.loadFeed('user1');

      expect(() => vm.deletePost('p1', 'user1'), throwsA(isA<Exception>()));
      expect(vm.posts, hasLength(2));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/home/posts_viewmodel_test.dart`
Expected: FAIL — `package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart` does not exist.

- [ ] **Step 3: Create `PostsViewModel`**

Create `lib/features/home/presentation/viewmodels/posts_viewmodel.dart`:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/models/post.dart';
import 'package:mvvm_sip_demo/services/posts_service.dart';

class PostsViewModel extends ChangeNotifier {
  PostsViewModel(this._service);

  final PostsService _service;

  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _currentPage < _totalPages;

  Future<void> loadFeed(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _service.fetchFeed(page: 1);
      _posts = page.posts;
      _currentPage = page.currentPage;
      _totalPages = page.totalPages;
    } catch (e) {
      _error = 'Failed to load posts. Check your connection and try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(String userId) async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _service.fetchFeed(page: _currentPage + 1);
      _posts = [..._posts, ...page.posts];
      _currentPage = page.currentPage;
      _totalPages = page.totalPages;
    } catch (e) {
      // Loading-more failures don't replace the already-loaded feed; the
      // UI shows a small inline retry affordance instead.
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String postId, String userId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final original = _posts[index];
    final wasLiked = original.isLikedBy(userId);
    final optimisticLikedBy = wasLiked
        ? original.likedBy.where((id) => id != userId).toList()
        : [...original.likedBy, userId];

    _posts = [
      ..._posts.sublist(0, index),
      _copyWithLikedBy(original, optimisticLikedBy),
      ..._posts.sublist(index + 1),
    ];
    notifyListeners();

    try {
      await _service.toggleLike(postId: postId, userId: userId);
      // Optimistic state already matches the toggle; nothing further to do.
    } catch (e) {
      final revertIndex = _posts.indexWhere((p) => p.id == postId);
      if (revertIndex == -1) return;
      _posts = [
        ..._posts.sublist(0, revertIndex),
        original,
        ..._posts.sublist(revertIndex + 1),
      ];
      notifyListeners();
    }
  }

  Post _copyWithLikedBy(Post post, List<String> likedBy) {
    return Post(
      id: post.id,
      type: post.type,
      caption: post.caption,
      mediaUrl: post.mediaUrl,
      audioTitle: post.audioTitle,
      authorUserId: post.authorUserId,
      authorName: post.authorName,
      likedBy: likedBy,
      commentCount: post.commentCount,
      createdAt: post.createdAt,
    );
  }

  Future<void> createPost({
    required PostType type,
    String? caption,
    required String authorUserId,
    required String authorName,
    String? audioTitle,
    File? mediaFile,
  }) async {
    final post = await _service.createPost(
      type: type,
      caption: caption,
      authorUserId: authorUserId,
      authorName: authorName,
      audioTitle: audioTitle,
      mediaFile: mediaFile,
    );
    _posts = [post, ..._posts];
    notifyListeners();
  }

  Future<void> deletePost(String postId, String authorUserId) async {
    await _service.deletePost(postId: postId, authorUserId: authorUserId);
    _posts = _posts.where((p) => p.id != postId).toList();
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/home/posts_viewmodel_test.dart`
Expected: PASS (11 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/viewmodels/posts_viewmodel.dart test/features/home/posts_viewmodel_test.dart
git commit -m "feat(posts): add PostsViewModel with optimistic like and pagination"
```

---

### Task 3: `FeedPostCard` + feed state widgets

**Files:**
- Modify: `pubspec.yaml` (add `video_player`, `share_plus`)
- Create: `lib/features/home/presentation/widgets/feed_post_card.dart`
- Create: `lib/features/home/presentation/widgets/feed_states.dart`
- Test: `test/features/home/feed_post_card_test.dart`

**Interfaces:**
- Consumes: `Post`, `PostType` (Task 1).
- Produces: `class FeedPostCard extends StatelessWidget` with constructor `FeedPostCard({required Post post, required String currentUserId, required VoidCallback onLikeTap, required VoidCallback onCommentTap, VoidCallback? onDeleteTap})`; `class FeedLoadingSkeleton`, `class FeedErrorState({required String message, required VoidCallback onRetry})`, `class FeedEmptyState({required VoidCallback onCompose})`, `class FeedLoadMoreRetry({required VoidCallback onRetry})` — all `StatelessWidget`. Consumed by Task 6.

- [ ] **Step 1: Add the new dependencies**

Run: `flutter pub add video_player share_plus`
Expected: `pubspec.yaml`'s `dependencies` gains `video_player` and `share_plus` (versions chosen by the tool); `pubspec.lock` updates accordingly.

- [ ] **Step 2: Write the failing tests**

Create `test/features/home/feed_post_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/feed_post_card.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/feed_states.dart';
import 'package:mvvm_sip_demo/models/post.dart';

Post _post({
  required PostType type,
  String? caption,
  String? mediaUrl,
  String? audioTitle,
  List<String> likedBy = const [],
  int commentCount = 0,
  String authorUserId = 'author1',
}) {
  return Post(
    id: 'p1',
    type: type,
    caption: caption,
    mediaUrl: mediaUrl,
    audioTitle: audioTitle,
    authorUserId: authorUserId,
    authorName: 'Alice Example',
    likedBy: likedBy,
    commentCount: commentCount,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  );
}

void main() {
  testWidgets('photo post renders the caption and author name', (tester) async {
    // mediaUrl is deliberately null here: this test only checks caption/
    // author text, not real image loading, and a real https:// URL would
    // make CachedNetworkImage attempt a genuine network request during the
    // test (slow, and a real live network call this suite must not make).
    // With mediaUrl null, _buildBody's photo case falls back to a plain
    // Container instead of CachedNetworkImage.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedPostCard(
          post: _post(type: PostType.photo, caption: 'Nice view', mediaUrl: null),
          currentUserId: 'someone-else',
          onLikeTap: () {},
          onCommentTap: () {},
        ),
      ),
    ));

    expect(find.text('Alice Example'), findsOneWidget);
    expect(find.text('Nice view'), findsOneWidget);
  });

  testWidgets('video post shows a play button before playback starts', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedPostCard(
          post: _post(type: PostType.video, mediaUrl: 'https://example.com/a.mp4'),
          currentUserId: 'someone-else',
          onLikeTap: () {},
          onCommentTap: () {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
  });

  testWidgets('audio post shows its title and a play button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedPostCard(
          post: _post(
              type: PostType.audio,
              audioTitle: 'Sunset drive mix',
              mediaUrl: 'https://example.com/a.mp3'),
          currentUserId: 'someone-else',
          onLikeTap: () {},
          onCommentTap: () {},
        ),
      ),
    ));

    expect(find.text('Sunset drive mix'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
  });

  testWidgets('text post renders only the caption, no media block', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedPostCard(
          post: _post(type: PostType.text, caption: 'Just words'),
          currentUserId: 'someone-else',
          onLikeTap: () {},
          onCommentTap: () {},
        ),
      ),
    ));

    expect(find.text('Just words'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);
  });

  testWidgets('tapping the like button invokes onLikeTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedPostCard(
          post: _post(type: PostType.text, caption: 'hi'),
          currentUserId: 'someone-else',
          onLikeTap: () => tapped = true,
          onCommentTap: () {},
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(tapped, true);
  });

  testWidgets('liked state shows a filled heart', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedPostCard(
          post: _post(type: PostType.text, caption: 'hi', likedBy: const ['me']),
          currentUserId: 'me',
          onLikeTap: () {},
          onCommentTap: () {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('shows a delete option only for the current user\'s own post',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedPostCard(
          post: _post(type: PostType.text, caption: 'mine', authorUserId: 'me'),
          currentUserId: 'me',
          onLikeTap: () {},
          onCommentTap: () {},
          onDeleteTap: () {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });

  testWidgets('hides the delete option for someone else\'s post', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedPostCard(
          post: _post(type: PostType.text, caption: 'not mine', authorUserId: 'other'),
          currentUserId: 'me',
          onLikeTap: () {},
          onCommentTap: () {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });

  testWidgets('FeedLoadingSkeleton renders without error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FeedLoadingSkeleton())));
    expect(find.byType(FeedLoadingSkeleton), findsOneWidget);
  });

  testWidgets('FeedErrorState shows the message and a retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedErrorState(message: 'Something went wrong', onRetry: () => retried = true),
      ),
    ));

    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, true);
  });

  testWidgets('FeedEmptyState shows the empty message and a compose button', (tester) async {
    var composed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FeedEmptyState(onCompose: () => composed = true)),
    ));

    expect(find.text('No posts yet — be the first to share'), findsOneWidget);
    await tester.tap(find.text('Share something'));
    expect(composed, true);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/home/feed_post_card_test.dart`
Expected: FAIL — the widget files don't exist yet.

- [ ] **Step 4: Create `feed_states.dart`**

Create `lib/features/home/presentation/widgets/feed_states.dart`:

```dart
import 'package:flutter/material.dart';

class FeedLoadingSkeleton extends StatelessWidget {
  const FeedLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 160,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class FeedErrorState extends StatelessWidget {
  const FeedErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class FeedEmptyState extends StatelessWidget {
  const FeedEmptyState({super.key, required this.onCompose});

  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text('No posts yet — be the first to share',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(onPressed: onCompose, child: const Text('Share something')),
        ],
      ),
    );
  }
}

class FeedLoadMoreRetry extends StatelessWidget {
  const FeedLoadMoreRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton(onPressed: onRetry, child: const Text('Load more failed — retry')),
      ),
    );
  }
}
```

- [ ] **Step 5: Create `feed_post_card.dart`**

Create `lib/features/home/presentation/widgets/feed_post_card.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/post.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onLikeTap,
    required this.onCommentTap,
    this.onDeleteTap,
  });

  final Post post;
  final String currentUserId;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback? onDeleteTap;

  String get _initials {
    final parts = post.authorName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  String get _relativeTime {
    final diff = DateTime.now().difference(post.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildBody(BuildContext context) {
    switch (post.type) {
      case PostType.photo:
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: post.mediaUrl != null
                ? CachedNetworkImage(imageUrl: post.mediaUrl!, fit: BoxFit.cover)
                : Container(color: Theme.of(context).colorScheme.surface),
          ),
        );
      case PostType.video:
        return _VideoBody(mediaUrl: post.mediaUrl);
      case PostType.audio:
        return _AudioBody(mediaUrl: post.mediaUrl, title: post.audioTitle ?? 'Audio');
      case PostType.text:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMine = post.authorUserId == currentUserId;
    final isLiked = post.isLikedBy(currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: WunzaColors.navIndicator.withValues(alpha: 0.18),
                child: Text(_initials,
                    style: TextStyle(color: WunzaColors.navIndicator, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(_relativeTime, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (isMine)
                PopupMenuButton<void>(
                  icon: const Icon(Icons.more_horiz),
                  itemBuilder: (context) => [
                    PopupMenuItem(onTap: onDeleteTap, child: const Text('Delete post')),
                  ],
                ),
            ],
          ),
          if (post.caption != null && post.caption!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(post.caption!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (post.type != PostType.text) ...[
            const SizedBox(height: 10),
            _buildBody(context),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _EngagementButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                iconColor: isLiked ? WunzaColors.padGradientEnd : null,
                label: '${post.likedBy.length}',
                onTap: onLikeTap,
              ),
              const SizedBox(width: 20),
              _EngagementButton(
                icon: Icons.mode_comment_outlined,
                label: '${post.commentCount}',
                onTap: onCommentTap,
              ),
              const SizedBox(width: 20),
              _EngagementButton(
                icon: Icons.share_outlined,
                label: 'Share',
                // share_plus 10+'s API: SharePlus.instance.share(ShareParams(...)).
                // If `flutter pub add share_plus` resolves an older major
                // version where this doesn't exist, use that version's
                // equivalent (older versions: the static `Share.share(text)`)
                // instead — the share behavior is what matters, not this
                // exact call shape.
                onTap: () => SharePlus.instance.share(
                  ShareParams(
                    text: (post.caption?.isNotEmpty ?? false)
                        ? post.caption!
                        : 'Check out this post on SuperApp',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EngagementButton extends StatelessWidget {
  const _EngagementButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor ?? Theme.of(context).hintColor),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _VideoBody extends StatefulWidget {
  const _VideoBody({required this.mediaUrl});
  final String? mediaUrl;

  @override
  State<_VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends State<_VideoBody> {
  VideoPlayerController? _controller;
  bool _playing = false;

  Future<void> _startPlayback() async {
    if (widget.mediaUrl == null) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl!));
    await controller.initialize();
    await controller.play();
    if (!mounted) return;
    setState(() {
      _controller = controller;
      _playing = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _playing && _controller != null
            ? Stack(
                alignment: Alignment.bottomRight,
                children: [
                  VideoPlayer(_controller!),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller!,
                      builder: (context, value, _) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : GestureDetector(
                onTap: _startPlayback,
                child: Container(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.18),
                  child: const Center(
                    child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white),
                  ),
                ),
              ),
      ),
    );
  }
}

class _AudioBody extends StatefulWidget {
  const _AudioBody({required this.mediaUrl, required this.title});
  final String? mediaUrl;
  final String title;

  @override
  State<_AudioBody> createState() => _AudioBodyState();
}

class _AudioBodyState extends State<_AudioBody> {
  final _player = AudioPlayer();
  bool _playing = false;

  Future<void> _toggle() async {
    if (widget.mediaUrl == null) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.mediaUrl!));
    }
    if (!mounted) return;
    setState(() => _playing = !_playing);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: WunzaColors.navIndicator.withValues(alpha: 0.18),
            ),
            child: Icon(Icons.music_note, color: WunzaColors.navIndicator),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          ),
          IconButton(
            icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
            onPressed: _toggle,
          ),
        ],
      ),
    );
  }
}
```

Note: tests must not tap the video/audio play buttons — doing so calls real `VideoPlayerController`/`AudioPlayer` platform channels, which aren't available in `flutter test`'s environment. The tests above only verify the pre-playback state (play icon visible), which is safe.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/home/feed_post_card_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/home/presentation/widgets/feed_post_card.dart lib/features/home/presentation/widgets/feed_states.dart test/features/home/feed_post_card_test.dart
git commit -m "feat(posts): add FeedPostCard and feed loading/error/empty states"
```

---

### Task 4: `ComposerBar` + `ComposerChoiceSheet`

**Files:**
- Create: `lib/features/home/presentation/widgets/composer_bar.dart`
- Create: `lib/features/home/presentation/widgets/composer_choice_sheet.dart`
- Test: `test/features/home/composer_bar_test.dart`

**Interfaces:**
- Consumes: `PostType` (Task 1).
- Produces: `class ComposerBar extends StatelessWidget` with constructor `ComposerBar({required String userInitials, required VoidCallback onTap})`; `class ComposerChoiceSheet` with static method `ComposerChoiceSheet.show(BuildContext context, ValueChanged<PostType> onChoice)`. Consumed by Task 6.

- [ ] **Step 1: Write the failing tests**

Create `test/features/home/composer_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/composer_bar.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/composer_choice_sheet.dart';
import 'package:mvvm_sip_demo/models/post.dart';

void main() {
  testWidgets('ComposerBar shows the placeholder text and initials, and invokes onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ComposerBar(userInitials: 'AB', onTap: () => tapped = true),
      ),
    ));

    expect(find.text('Share something...'), findsOneWidget);
    expect(find.text('AB'), findsOneWidget);

    await tester.tap(find.byType(ComposerBar));
    expect(tapped, true);
  });

  testWidgets('ComposerChoiceSheet shows all 4 options and reports the chosen type',
      (tester) async {
    PostType? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ComposerChoiceSheet.show(context, (type) => chosen = type),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);

    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    expect(chosen, PostType.video);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/home/composer_bar_test.dart`
Expected: FAIL — the widget files don't exist yet.

- [ ] **Step 3: Create `composer_bar.dart`**

Create `lib/features/home/presentation/widgets/composer_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class ComposerBar extends StatelessWidget {
  const ComposerBar({super.key, required this.userInitials, required this.onTap});

  final String userInitials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: WunzaColors.navIndicator.withValues(alpha: 0.18),
              child: Text(userInitials,
                  style: TextStyle(
                      color: WunzaColors.navIndicator, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Share something...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
            ),
            Icon(Icons.image_outlined, color: Theme.of(context).hintColor, size: 20),
            const SizedBox(width: 8),
            Icon(Icons.videocam_outlined, color: Theme.of(context).hintColor, size: 20),
            const SizedBox(width: 8),
            Icon(Icons.mic_outlined, color: Theme.of(context).hintColor, size: 20),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `composer_choice_sheet.dart`**

Create `lib/features/home/presentation/widgets/composer_choice_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/models/post.dart';

class ComposerChoiceSheet extends StatelessWidget {
  const ComposerChoiceSheet({super.key, required this.onChoice});

  final ValueChanged<PostType> onChoice;

  static Future<void> show(BuildContext context, ValueChanged<PostType> onChoice) {
    return showModalBottomSheet(
      context: context,
      builder: (_) => ComposerChoiceSheet(onChoice: onChoice),
    );
  }

  void _choose(BuildContext context, PostType type) {
    Navigator.pop(context);
    onChoice(type);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _ChoiceTile(
            icon: Icons.image_outlined,
            label: 'Photo',
            onTap: () => _choose(context, PostType.photo),
          ),
          _ChoiceTile(
            icon: Icons.videocam_outlined,
            label: 'Video',
            onTap: () => _choose(context, PostType.video),
          ),
          _ChoiceTile(
            icon: Icons.text_fields,
            label: 'Text',
            onTap: () => _choose(context, PostType.text),
          ),
          _ChoiceTile(
            icon: Icons.mic_outlined,
            label: 'Audio',
            onTap: () => _choose(context, PostType.audio),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/home/composer_bar_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/presentation/widgets/composer_bar.dart lib/features/home/presentation/widgets/composer_choice_sheet.dart test/features/home/composer_bar_test.dart
git commit -m "feat(posts): add ComposerBar and ComposerChoiceSheet"
```

---

### Task 5: Composer creation views (photo/video, text, audio)

**Files:**
- Modify: `pubspec.yaml` (add `file_picker`)
- Create: `lib/features/home/presentation/views/composer_photo_video_view.dart`
- Create: `lib/features/home/presentation/views/composer_text_view.dart`
- Create: `lib/features/home/presentation/views/composer_audio_view.dart`
- Test: `test/features/home/composer_views_test.dart`

**Interfaces:**
- Consumes: `PostsViewModel` (Task 2, via `Provider`/`context.read`), `PostType` (Task 1).
- Produces: `class ComposerPhotoVideoView extends StatefulWidget` with constructor `ComposerPhotoVideoView({required PostType type, required String authorUserId, required String authorName, Future<XFile?> Function()? pickFile})`; `class ComposerTextView extends StatefulWidget` with constructor `ComposerTextView({required String authorUserId, required String authorName})`; `class ComposerAudioView extends StatefulWidget` with constructor `ComposerAudioView({required String authorUserId, required String authorName, Future<String?> Function()? pickFile})`. Consumed by Task 6. All 3 require a `PostsViewModel` to be available via `Provider` above them in the widget tree.

- [ ] **Step 1: Add the new dependency**

Run: `flutter pub add file_picker`
Expected: `pubspec.yaml`'s `dependencies` gains `file_picker`.

- [ ] **Step 2: Write the failing tests**

Create `test/features/home/composer_views_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart';
import 'package:mvvm_sip_demo/features/home/presentation/views/composer_audio_view.dart';
import 'package:mvvm_sip_demo/features/home/presentation/views/composer_photo_video_view.dart';
import 'package:mvvm_sip_demo/features/home/presentation/views/composer_text_view.dart';
import 'package:mvvm_sip_demo/models/post.dart';
import 'package:mvvm_sip_demo/services/posts_service.dart';

class _FakePostsService implements PostsService {
  bool failCreate = false;
  Post? lastCreated;

  @override
  Future<FeedPage> fetchFeed({required int page, int limit = 10}) async =>
      const FeedPage(posts: [], totalPages: 1, currentPage: 1);

  @override
  Future<Post> createPost({
    required PostType type,
    String? caption,
    required String authorUserId,
    required String authorName,
    String? audioTitle,
    File? mediaFile,
  }) async {
    if (failCreate) throw Exception('upload failed');
    final post = Post(
      id: 'new',
      type: type,
      caption: caption,
      audioTitle: audioTitle,
      authorUserId: authorUserId,
      authorName: authorName,
      likedBy: const [],
      commentCount: 0,
      createdAt: DateTime.now(),
    );
    lastCreated = post;
    return post;
  }

  @override
  Future<LikeResult> toggleLike({required String postId, required String userId}) async =>
      const LikeResult(liked: true, likeCount: 1);

  @override
  Future<void> deletePost({required String postId, required String authorUserId}) async {}
}

Widget _wrap(Widget child, PostsViewModel vm) {
  return ChangeNotifierProvider<PostsViewModel>.value(value: vm, child: MaterialApp(home: child));
}

void main() {
  testWidgets('ComposerTextView posts the typed text and pops on success', (tester) async {
    final fake = _FakePostsService();
    final vm = PostsViewModel(fake);

    await tester.pumpWidget(
        _wrap(const ComposerTextView(authorUserId: 'user1', authorName: 'Alice'), vm));

    await tester.enterText(find.byType(TextField), 'Hello world');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(fake.lastCreated?.caption, 'Hello world');
    expect(fake.lastCreated?.type, PostType.text);
  });

  testWidgets('ComposerTextView shows an error and stays open on failure', (tester) async {
    final fake = _FakePostsService()..failCreate = true;
    final vm = PostsViewModel(fake);

    await tester.pumpWidget(
        _wrap(const ComposerTextView(authorUserId: 'user1', authorName: 'Alice'), vm));

    await tester.enterText(find.byType(TextField), 'Hello world');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to post. Please try again.'), findsOneWidget);
  });

  testWidgets('ComposerPhotoVideoView posts with the picked file and caption', (tester) async {
    final fake = _FakePostsService();
    final vm = PostsViewModel(fake);

    await tester.pumpWidget(_wrap(
      ComposerPhotoVideoView(
        type: PostType.photo,
        authorUserId: 'user1',
        authorName: 'Alice',
        pickFile: () async => XFile('/tmp/fake.png'),
      ),
      vm,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Nice shot');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(fake.lastCreated?.type, PostType.photo);
    expect(fake.lastCreated?.caption, 'Nice shot');
  });

  testWidgets('ComposerPhotoVideoView shows a retry affordance when no file was picked',
      (tester) async {
    final fake = _FakePostsService();
    final vm = PostsViewModel(fake);

    await tester.pumpWidget(_wrap(
      ComposerPhotoVideoView(
        type: PostType.video,
        authorUserId: 'user1',
        authorName: 'Alice',
        pickFile: () async => null,
      ),
      vm,
    ));
    await tester.pumpAndSettle();

    expect(find.text('No file selected'), findsOneWidget);
  });

  testWidgets('ComposerAudioView posts with the picked file path and title', (tester) async {
    final fake = _FakePostsService();
    final vm = PostsViewModel(fake);

    await tester.pumpWidget(_wrap(
      ComposerAudioView(
        authorUserId: 'user1',
        authorName: 'Alice',
        pickFile: () async => '/tmp/clip.mp3',
      ),
      vm,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Selected: clip.mp3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sunset drive mix');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(fake.lastCreated?.type, PostType.audio);
    expect(fake.lastCreated?.audioTitle, 'Sunset drive mix');
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/home/composer_views_test.dart`
Expected: FAIL — the view files don't exist yet.

- [ ] **Step 4: Create `composer_text_view.dart`**

Create `lib/features/home/presentation/views/composer_text_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart';
import 'package:mvvm_sip_demo/models/post.dart';

class ComposerTextView extends StatefulWidget {
  const ComposerTextView({super.key, required this.authorUserId, required this.authorName});

  final String authorUserId;
  final String authorName;

  @override
  State<ComposerTextView> createState() => _ComposerTextViewState();
}

class _ComposerTextViewState extends State<ComposerTextView> {
  final _textController = TextEditingController();
  bool _posting = false;
  String? _error;

  Future<void> _post() async {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await context.read<PostsViewModel>().createPost(
            type: PostType.text,
            caption: _textController.text.trim(),
            authorUserId: widget.authorUserId,
            authorName: widget.authorName,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Failed to post. Please try again.';
        _posting = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New text post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(hintText: "What's on your mind?"),
              maxLines: 8,
              autofocus: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _posting ? null : _post,
              child: _posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create `composer_photo_video_view.dart`**

Create `lib/features/home/presentation/views/composer_photo_video_view.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart';
import 'package:mvvm_sip_demo/models/post.dart';

class ComposerPhotoVideoView extends StatefulWidget {
  const ComposerPhotoVideoView({
    super.key,
    required this.type,
    required this.authorUserId,
    required this.authorName,
    this.pickFile,
  });

  final PostType type;
  final String authorUserId;
  final String authorName;
  final Future<XFile?> Function()? pickFile;

  @override
  State<ComposerPhotoVideoView> createState() => _ComposerPhotoVideoViewState();
}

class _ComposerPhotoVideoViewState extends State<ComposerPhotoVideoView> {
  final _captionController = TextEditingController();
  XFile? _picked;
  bool _posting = false;
  bool _pickAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final pickFn = widget.pickFile ??
        () => widget.type == PostType.photo
            ? ImagePicker().pickImage(source: ImageSource.gallery)
            : ImagePicker().pickVideo(source: ImageSource.gallery);
    final file = await pickFn();
    if (!mounted) return;
    setState(() {
      _picked = file;
      _pickAttempted = true;
    });
  }

  Future<void> _post() async {
    if (_picked == null) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await context.read<PostsViewModel>().createPost(
            type: widget.type,
            caption:
                _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
            authorUserId: widget.authorUserId,
            authorName: widget.authorName,
            mediaFile: File(_picked!.path),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Failed to post. Please try again.';
        _posting = false;
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == PostType.photo ? 'New photo post' : 'New video post'),
      ),
      body: !_pickAttempted
          ? const Center(child: CircularProgressIndicator())
          : _picked == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No file selected'),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _pick, child: const Text('Choose again')),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.type == PostType.photo)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(_picked!.path),
                            height: 200,
                            fit: BoxFit.cover,
                            // A real device photo always resolves, but this
                            // guards against a picked-then-deleted file — and
                            // keeps widget tests deterministic, since a test's
                            // injected `pickFile` returns a path that doesn't
                            // exist on the test-running machine.
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 200,
                              color: Theme.of(context).colorScheme.surface,
                              child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(child: Icon(Icons.videocam, size: 48)),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _captionController,
                        decoration: const InputDecoration(hintText: 'Write a caption...'),
                        maxLines: 3,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _posting ? null : _post,
                        child: _posting
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Post'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
```

- [ ] **Step 6: Create `composer_audio_view.dart`**

Create `lib/features/home/presentation/views/composer_audio_view.dart`:

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart';
import 'package:mvvm_sip_demo/models/post.dart';

class ComposerAudioView extends StatefulWidget {
  const ComposerAudioView({
    super.key,
    required this.authorUserId,
    required this.authorName,
    this.pickFile,
  });

  final String authorUserId;
  final String authorName;
  final Future<String?> Function()? pickFile;

  @override
  State<ComposerAudioView> createState() => _ComposerAudioViewState();
}

class _ComposerAudioViewState extends State<ComposerAudioView> {
  final _titleController = TextEditingController();
  String? _pickedPath;
  bool _posting = false;
  bool _pickAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final pickFn = widget.pickFile ?? _defaultPick;
    final path = await pickFn();
    if (!mounted) return;
    setState(() {
      _pickedPath = path;
      _pickAttempted = true;
    });
  }

  Future<String?> _defaultPick() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    return result?.files.single.path;
  }

  Future<void> _post() async {
    if (_pickedPath == null) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await context.read<PostsViewModel>().createPost(
            type: PostType.audio,
            audioTitle:
                _titleController.text.trim().isEmpty ? 'Untitled' : _titleController.text.trim(),
            authorUserId: widget.authorUserId,
            authorName: widget.authorName,
            mediaFile: File(_pickedPath!),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Failed to post. Please try again.';
        _posting = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New audio post')),
      body: !_pickAttempted
          ? const Center(child: CircularProgressIndicator())
          : _pickedPath == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No file selected'),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _pick, child: const Text('Choose again')),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected: ${_pickedPath!.split('/').last}'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(hintText: 'Title (e.g. Sunset drive mix)'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _posting ? null : _post,
                        child: _posting
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Post'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/home/composer_views_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/home/presentation/views/composer_text_view.dart lib/features/home/presentation/views/composer_photo_video_view.dart lib/features/home/presentation/views/composer_audio_view.dart test/features/home/composer_views_test.dart
git commit -m "feat(posts): add photo/video, text, and audio composer views"
```

---

### Task 6: Wire into `ExploreTab` and app-level DI

**Files:**
- Modify: `lib/core/di/inject.dart` (register `PostsService`/`PostsViewModel`)
- Modify: `lib/main.dart` (add `PostsViewModel` to the app's `MultiProvider`)
- Modify: `lib/features/home/presentation/widgets/explore_tab.dart` (add composer bar + feed slivers)

**Interfaces:**
- Consumes: `PostsService`/`PostsViewModel` (Tasks 1-2), `FeedPostCard`/feed state widgets (Task 3), `ComposerBar`/`ComposerChoiceSheet` (Task 4), the 3 composer views (Task 5).
- Produces: no new public interfaces — this is the final integration point.

- [ ] **Step 1: Register `PostsService`/`PostsViewModel` in `get_it`**

In `lib/core/di/inject.dart`, add these imports alongside the existing `shopping_service.dart`/`shopping_viewmodel.dart` imports (find `import '../../services/shopping_service.dart';` at line 31 and `import '../../features/shopping/presentation/viewmodels/shopping_viewmodel.dart';` at line 35, and add these two lines near them):

```dart
import '../../services/posts_service.dart';
import '../../features/home/presentation/viewmodels/posts_viewmodel.dart';
```

Then find this block (around line 108-118):

```dart
  // Services
  getIt.registerLazySingleton<CallingService>(() => CallingService());
  getIt.registerLazySingleton<ShoppingService>(() => ShoppingService());
  getIt.registerLazySingleton<ShippingAddressService>(() => ShippingAddressService());
  getIt.registerLazySingleton<UtilityBillsService>(() => UtilityBillsService());
  getIt.registerLazySingleton<AfricomPaymentService>(
      () => const AfricomPaymentService());
  // ViewModels
  getIt.registerFactory(() => DashboardViewModel(getIt(), getIt(), getIt()));
  getIt.registerFactory(() => ShoppingViewModel(getIt()));
```

Add `PostsService` right after `ShoppingService`, and `PostsViewModel` right after `ShoppingViewModel`:

```dart
  // Services
  getIt.registerLazySingleton<CallingService>(() => CallingService());
  getIt.registerLazySingleton<ShoppingService>(() => ShoppingService());
  getIt.registerLazySingleton<PostsService>(() => PostsService());
  getIt.registerLazySingleton<ShippingAddressService>(() => ShippingAddressService());
  getIt.registerLazySingleton<UtilityBillsService>(() => UtilityBillsService());
  getIt.registerLazySingleton<AfricomPaymentService>(
      () => const AfricomPaymentService());
  // ViewModels
  getIt.registerFactory(() => DashboardViewModel(getIt(), getIt(), getIt()));
  getIt.registerFactory(() => ShoppingViewModel(getIt()));
  getIt.registerFactory(() => PostsViewModel(getIt()));
```

- [ ] **Step 2: Add `PostsViewModel` to the app's `MultiProvider`**

In `lib/main.dart`, add the import alongside the existing viewmodel imports (near line 20):

```dart
import 'features/home/presentation/viewmodels/posts_viewmodel.dart';
```

Then find the `MultiProvider`'s `providers` list (lines 59-70) and add a new line after `ChangeNotifierProvider(create: (_) => getIt<ShoppingViewModel>()),`:

```dart
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => getIt<DashboardViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<ShoppingViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<PostsViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<UtilityBillsViewModel>()),
```

(Only that one new line is added; the rest of the list is unchanged.)

- [ ] **Step 3: Verify the project compiles**

Run: `flutter analyze lib/core/di/inject.dart lib/main.dart`
Expected: "No issues found!" (or only pre-existing issues unrelated to these two files).

- [ ] **Step 4: Rewrite `explore_tab.dart` to add the composer bar and feed**

Replace the entire contents of `lib/features/home/presentation/widgets/explore_tab.dart` with:

```dart
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
```

- [ ] **Step 5: Confirm the existing Explore tests still pass**

`ExploreTab`'s existing tests (`test/features/home/explore_tab_test.dart`) pump `MaterialApp(home: Scaffold(body: ExploreTab()))` with no `Provider` ancestor — since `ExploreTab` now reads `PostsViewModel`/`AccountSummaryViewModel` via `context.watch`/`context.read`, those tests will now fail with a `ProviderNotFoundException`. This is expected and is not this task's concern to fix — a real `HomeView`-level integration test would need the full app's `MultiProvider`/DI setup (network calls, `get_it`, `SharedPreferences`), which is impractical in a widget test, matching the same reasoning documented in the glass-bottom-nav plan's Task 6 ("no automated test — DI/Provider/network dependencies make it impractical, manual verification covers this instead").

Run: `flutter analyze lib/features/home/presentation/widgets/explore_tab.dart`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/core/di/inject.dart lib/main.dart lib/features/home/presentation/widgets/explore_tab.dart
git commit -m "feat(posts): wire ComposerBar and feed into ExploreTab"
```

---

## Manual verification (no automated task — same rationale as prior integration tasks in this app)

After all 6 tasks are done, run the app against the real (deployed) backend and check:
- Explore tab loads a real feed below the discovery sections (skeleton while loading, real posts once loaded).
- Composer bar → choice sheet → each of Photo/Video/Text/Audio opens its flow, picks/records nothing live (audio picks an existing file), posts successfully, and the new post appears at the top of the feed without needing to leave and re-enter Explore.
- Liking a post fills the heart and increments the count instantly (optimistic); confirm it's still liked after backgrounding/reopening the app (i.e., it actually persisted, not just a local-only flip).
- Tapping Share opens the native OS share sheet.
- Tapping the comment icon opens the "Coming soon" placeholder.
- Deleting your own post (via the overflow menu) removes it from the feed; posts from other accounts (if any test data exists) show no delete option.
- Scrolling to the bottom of the feed loads more posts automatically; reaching the true end shows nothing further (no infinite spinner).
- Turning off wifi/data and reloading Explore shows the feed's error state with a working "Try again".
