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
    if (failFetch) {
      return FeedPage(posts: const [], totalPages: 1, currentPage: page, ok: false);
    }
    if (page == 1) {
      return FeedPage(posts: feedPage1, totalPages: totalPages, currentPage: 1, ok: true);
    }
    return FeedPage(posts: feedPage2, totalPages: totalPages, currentPage: 2, ok: true);
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

    test(
        'sets loadMoreFailed and preserves the already-loaded feed when a page fails, and a subsequent retry succeeds',
        () async {
      final fake = FakePostsService();
      final vm = PostsViewModel(fake);
      await vm.loadFeed('user1');

      fake.failFetch = true;
      await vm.loadMore('user1');

      expect(vm.posts, hasLength(2), reason: 'the already-loaded feed must not be wiped by a failed page');
      expect(vm.hasMore, true, reason: 'hasMore must not be truncated by a failed page');
      expect(vm.loadMoreFailed, true);

      fake.failFetch = false;
      await vm.loadMore('user1');

      expect(vm.posts, hasLength(3));
      expect(vm.loadMoreFailed, false);
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
