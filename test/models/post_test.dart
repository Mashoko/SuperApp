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
