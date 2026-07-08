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
