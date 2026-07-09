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
      const FeedPage(posts: [], totalPages: 1, currentPage: 1, ok: true);

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
