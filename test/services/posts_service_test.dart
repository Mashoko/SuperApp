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
      expect(page.ok, true);
    });

    test('returns an empty page on a non-200 response', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = PostsService(client: mockClient);

      final page = await service.fetchFeed(page: 1);

      expect(page.posts, isEmpty);
      expect(page.ok, false);
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
