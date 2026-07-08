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
