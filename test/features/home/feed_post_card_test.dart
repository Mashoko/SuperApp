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
