import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart';
import 'package:mvvm_sip_demo/models/post.dart';

class ComposerTextView extends StatefulWidget {
  const ComposerTextView({super.key, required this.authorUserId, required this.authorName});

  final String authorUserId;
  final String authorName;

  @override
  State<ComposerTextView> createState() => _ComposerTextViewState();
}

class _ComposerTextViewState extends State<ComposerTextView> {
  final _textController = TextEditingController();
  bool _posting = false;
  String? _error;

  Future<void> _post() async {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await context.read<PostsViewModel>().createPost(
            type: PostType.text,
            caption: _textController.text.trim(),
            authorUserId: widget.authorUserId,
            authorName: widget.authorName,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Failed to post. Please try again.';
        _posting = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New text post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(hintText: "What's on your mind?"),
              maxLines: 8,
              autofocus: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _posting ? null : _post,
              child: _posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}
