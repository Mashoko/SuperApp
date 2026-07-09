import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/models/post.dart';
import 'package:mvvm_sip_demo/services/posts_service.dart';

class PostsViewModel extends ChangeNotifier {
  PostsViewModel(this._service);

  final PostsService _service;

  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _loadMoreFailed = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get loadMoreFailed => _loadMoreFailed;
  String? get error => _error;
  bool get hasMore => _currentPage < _totalPages;

  Future<void> loadFeed(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final page = await _service.fetchFeed(page: 1);
    if (page.ok) {
      _posts = page.posts;
      _currentPage = page.currentPage;
      _totalPages = page.totalPages;
      _error = null;
    } else {
      _error = 'Failed to load posts. Check your connection and try again.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore(String userId) async {
    if (_isLoadingMore || !hasMore) return;

    _loadMoreFailed = false;
    _isLoadingMore = true;
    notifyListeners();

    final page = await _service.fetchFeed(page: _currentPage + 1);
    if (page.ok) {
      _posts = [..._posts, ...page.posts];
      _currentPage = page.currentPage;
      _totalPages = page.totalPages;
    } else {
      // Loading-more failures don't replace the already-loaded feed; the
      // UI shows a small inline retry affordance instead.
      _loadMoreFailed = true;
    }
    _isLoadingMore = false;
    notifyListeners();
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
