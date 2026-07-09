import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mvvm_sip_demo/models/post.dart';

class FeedPage {
  const FeedPage({
    required this.posts,
    required this.totalPages,
    required this.currentPage,
    required this.ok,
  });

  final List<Post> posts;
  final int totalPages;
  final int currentPage;
  final bool ok;
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
          ok: true,
        );
      }
      return FeedPage(posts: const [], totalPages: 1, currentPage: page, ok: false);
    } catch (e) {
      return FeedPage(posts: const [], totalPages: 1, currentPage: page, ok: false);
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
