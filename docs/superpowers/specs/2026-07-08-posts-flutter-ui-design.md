# Posts Flutter UI — Design Spec

Date: 2026-07-08
Status: Approved, pending implementation plan

## Context

This is the Flutter half of "Posts + Feed + Composer," the first slice of the
user's social-layer request (stories, composer, feed), sequenced after its
backend half. The backend
(`docs/superpowers/specs/2026-07-08-posts-backend-api-design.md` /
`docs/superpowers/plans/2026-07-08-posts-backend-api.md`) is complete,
reviewed, and deployed-ready: a `Post` model and REST API (`GET /api/posts`,
`POST /api/posts`, `POST /api/posts/:id/like`, `DELETE /api/posts/:id`) on
the existing Node/Express/Mongoose backend, unauthenticated but
`userId`-scoped, matching the app's existing cart/wishlist convention.

This spec covers everything needed to consume that API from the Flutter
app: a composer (4 post types: photo/video/text/audio), a feed of mixed post
cards, and wiring both into the top-level `ExploreTab` built in the earlier
discovery-hub project.

Unlike the discovery-hub UI (deliberately static placeholder data), this is
**real data** — the feed genuinely fetches, paginates, and can fail, so it
gets real loading/error/empty states, unlike the static sections above it.

## Goals

- A `PostsService`/`Post` model/`PostsViewModel` data layer matching this
  app's existing conventions exactly (`ShoppingService`'s raw-`http`,
  per-endpoint style; `ChangeNotifier`-based viewmodel).
- A composer: tap a bar → choose Photo/Video/Text/Audio → a minimal
  type-specific creation flow → post.
- A feed of `FeedPostCard`s (shared header/engagement chrome, type-specific
  bodies) with real per-user like toggling (optimistic), a native share
  sheet, and author-only delete.
- Infinite-scroll pagination.
- Real loading/error/empty states for the feed specifically.
- Wired into `ExploreTab`, positioned below the existing (unchanged)
  discovery sections, as the page's scrolling tail.

## Non-goals

- Stories — separate future spec (per the earlier sequencing decision).
- Real comment threads — the comment icon shows `commentCount` and opens the
  existing `MaintenanceScreen` placeholder, matching the backend spec's
  scope exactly.
- The "live" feel polish from the user's original request: a "new post"
  appeared-while-you-were-browsing pill, and folding "Nearby offers"/
  "Recently added" into the feed as badged card types. Both explicitly
  deferred to a later round once real posts/feed exist to react to.
- Video/audio duration pre-computed at compose time (`durationSeconds` stays
  unset on creation) — real duration is still shown live during playback via
  the player's own metadata, just not stored or shown before playback starts.
- Audio recording — the audio composer picks an existing file
  (`file_picker`), it does not record a new voice note live.
- A dedicated single-post detail screen — cards are fully inline, matching
  the backend's scope (there's no `GET /api/posts/:id` endpoint).

## File structure

- Create: `lib/models/post.dart` — the client-side `Post` data class.
- Create: `lib/services/posts_service.dart` — the HTTP client for the 4
  backend endpoints, matching `ShoppingService`'s style.
- Create: `lib/features/home/presentation/viewmodels/posts_viewmodel.dart` —
  feed state, pagination, optimistic like, post creation/deletion.
- Create: `lib/features/home/presentation/widgets/composer_bar.dart` — the
  "Share something..." entry row.
- Create: `lib/features/home/presentation/widgets/composer_choice_sheet.dart`
  — the 4-option bottom sheet.
- Create: `lib/features/home/presentation/views/composer_photo_video_view.dart`,
  `composer_text_view.dart`, `composer_audio_view.dart` — the 3 minimal
  creation flows (photo and video share one view, parameterized by type).
- Create: `lib/features/home/presentation/widgets/feed_post_card.dart` — the
  shared card chrome + 4 type-specific bodies.
- Create: `lib/features/home/presentation/widgets/feed_states.dart` —
  loading skeleton, error, and empty-state widgets for the feed.
- Modify: `lib/features/home/presentation/widgets/explore_tab.dart` — add
  the composer bar + feed as new slivers below the existing discovery
  sections.
- Modify: `pubspec.yaml` — add `file_picker`, `share_plus`, `video_player`.

## Data model

`lib/models/post.dart`:

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

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['_id'] as String,
        type: PostType.values.byName(json['type'] as String),
        caption: json['caption'] as String?,
        mediaUrl: json['mediaUrl'] as String?,
        audioTitle: json['audioTitle'] as String?,
        authorUserId: json['authorUserId'] as String,
        authorName: json['authorName'] as String,
        likedBy: (json['likedBy'] as List).cast<String>(),
        commentCount: json['commentCount'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
```

## `PostsService`

Matches `ShoppingService`'s existing style: same hardcoded base URL
constant, raw `http` calls, one method per endpoint, multipart for upload.

```dart
class PostsService {
  static const String _base = 'https://superapp-diht.onrender.com/api';

  Future<({List<Post> posts, int totalPages, int currentPage})> fetchFeed({
    required int page,
    int limit = 10,
  }); // GET /posts?page=&limit=

  Future<Post> createPost({
    required PostType type,
    String? caption,
    required String authorUserId,
    required String authorName,
    String? audioTitle,
    File? mediaFile,
  }); // POST /posts (multipart), throws on failure

  Future<({bool liked, int likeCount})> toggleLike({
    required String postId,
    required String userId,
  }); // POST /posts/:id/like, throws on failure

  Future<void> deletePost({
    required String postId,
    required String authorUserId,
  }); // DELETE /posts/:id, throws on failure
}
```

`fetchFeed` follows `ShoppingService`'s silent-fallback convention (returns
an empty page on failure) since a failed feed page is recoverable via retry
UI, not exceptional. `createPost`/`toggleLike`/`deletePost` throw on
failure — these are user-initiated actions where silent failure would be
actively misleading (e.g., a post that appears to succeed but never made it
to the server).

## `PostsViewModel`

`ChangeNotifier`, matching `ShoppingViewModel`'s pattern:

```dart
class PostsViewModel extends ChangeNotifier {
  List<Post> get posts;
  bool get isLoading;
  bool get isLoadingMore;
  String? get error;
  bool get hasMore;

  Future<void> loadFeed(String userId); // first page, resets state
  Future<void> loadMore(String userId); // next page, appends, no-op if !hasMore or already loading
  Future<void> toggleLike(String postId, String userId); // optimistic flip, revert on failure
  Future<void> createPost({...}); // calls service, prepends on success, rethrows on failure for the composer to show an error
  Future<void> deletePost(String postId, String userId); // calls service, removes from `posts` on success
}
```

`authorUserId` for creation/likes/deletes is the same `OtpAuthService`
`username` string already used throughout the shopping features.
`authorName` is `AccountSummaryViewModel.alias` (the display name already
shown in `HomeTopBar`) — resolved by the caller (`ExploreTab`/composer
views) via `Provider`, not fetched inside `PostsViewModel` itself, keeping
the viewmodel free of a dependency on `AccountSummaryViewModel`.

## Composer

`ComposerBar` (styled like the mockup's "Share something..." row: avatar
initials circle, muted placeholder text, small photo/video/audio trailing
icons) sits directly above the feed. Tapping it (or any of the trailing
icons, which just pre-select that choice) opens `ComposerChoiceSheet`, a
bottom sheet with 4 options.

- **Photo/Video** → `ComposerPhotoVideoView(type: PostType.photo | .video)`:
  `image_picker`'s `pickImage()`/`pickVideo()` launches immediately on
  entry; once a file is picked, shows a preview (image, or a
  `video_player`-initialized first frame for video) with a caption field and
  a "Post" button.
- **Text** → `ComposerTextView`: a full-screen text field, "Post" button, no
  media step.
- **Audio** → `ComposerAudioView`: `file_picker` (filtered to audio types)
  launches immediately; once picked, shows the file name, a title field
  (→ `audioTitle`), and a "Post" button.

All 3 views call `PostsViewModel.createPost(...)`. While in flight, "Post"
shows a spinner and is disabled; on success, the view pops back to Explore
(the new post is already prepended in `posts`, no re-fetch needed); on
failure, an inline error message with a "Try again" button that re-attempts
the same call.

## Feed cards

`FeedPostCard` provides shared chrome (avatar-initials circle, author name,
relative timestamp via a simple "Xh ago"/"Xm ago" formatter — no new
dependency, matches the mockup's own text), followed by a type-specific
body, followed by the engagement row.

**Bodies:**
- **Photo**: `CachedNetworkImage(mediaUrl)`, 16:9, `BoxFit.cover`.
- **Video**: 16:9 placeholder block (solid tint, no thumbnail generation
  per the backend's scope) with a centered play button; tapping swaps in an
  inline `video_player` view, duration shown live once loaded (not stored).
- **Audio**: compact horizontal row — icon block, `audioTitle`, a
  play/pause `IconButton` driving `audioplayers` (already a dependency).
- **Text**: just the caption, no media block.

**Engagement row** (shared): heart + `likedBy.length` (tap →
`PostsViewModel.toggleLike`, optimistic fill/empty + count change,
reverted if the backend call fails); comment icon + `commentCount` (tap →
existing `MaintenanceScreen`, "Comments" label); share icon + "Share" text
(tap → `share_plus`'s `Share.share(...)` with the caption/media URL, no
backend involvement, no persisted count, per the earlier decision).

Cards where `post.authorUserId == current userId` get a trailing overflow
button → "Delete post" → confirmation dialog → `PostsViewModel.deletePost`,
since the backend already supports author-only soft delete and leaving it
unreachable from the UI would be dead functionality.

## Page composition

`ExploreTab`'s `CustomScrollView` gains new slivers, appended after the
existing (unchanged) discovery sections: `ComposerBar` (as a
`SliverToBoxAdapter`), then the feed as a `SliverList` — not a nested
scrollable, avoiding scroll-within-scroll. A `ScrollController` on the outer
`CustomScrollView` triggers `PostsViewModel.loadMore(userId)` when the user
nears the bottom.

**Feed states** (`feed_states.dart`):
- **Initial load**: 3 skeleton `FeedPostCard`-shaped placeholder boxes.
- **Error** (first load failed): centered message + "Try again" button.
- **Empty** (loaded, zero posts): "No posts yet — be the first to share" +
  a button opening the composer.
- **Loading more**: small spinner at the list's end; a `loadMore` failure
  shows a small inline retry row rather than replacing the already-loaded
  feed.

## New dependencies

`file_picker` (audio file selection), `share_plus` (native share sheet),
`video_player` (video playback and live duration display) — added to
`pubspec.yaml`.

## Testing

- `PostsService`: unit tests using a mocked `http.Client` (via the `http`
  package's `MockClient` from `package:http/testing.dart`) — no live
  network calls.
- `PostsViewModel`: tests using a fake `PostsService` — load/loadMore
  pagination, optimistic like + revert-on-failure, create/delete mutating
  `posts` correctly.
- Widget tests: `ComposerChoiceSheet` (4 options render and navigate
  correctly), `FeedPostCard` (each of the 4 types renders its correct body;
  engagement row present; like tap updates visually), and the loading/
  error/empty state widgets. No live network calls in any widget test.

## Open items deferred to later specs

- Stories.
- The "new post" live-update pill and folding other content types into the
  feed as badged cards ("live" feel polish round).
- Real comment threads.
- Video/audio duration pre-computed and stored at compose time.
- Audio recording (vs. picking an existing file).
- A dedicated single-post detail/permalink screen.
