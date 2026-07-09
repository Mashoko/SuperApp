import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart';
import 'package:mvvm_sip_demo/models/post.dart';

class ComposerPhotoVideoView extends StatefulWidget {
  const ComposerPhotoVideoView({
    super.key,
    required this.type,
    required this.authorUserId,
    required this.authorName,
    this.pickFile,
  });

  final PostType type;
  final String authorUserId;
  final String authorName;
  final Future<XFile?> Function()? pickFile;

  @override
  State<ComposerPhotoVideoView> createState() => _ComposerPhotoVideoViewState();
}

class _ComposerPhotoVideoViewState extends State<ComposerPhotoVideoView> {
  final _captionController = TextEditingController();
  XFile? _picked;
  bool _posting = false;
  bool _pickAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final pickFn = widget.pickFile ??
        () => widget.type == PostType.photo
            ? ImagePicker().pickImage(source: ImageSource.gallery)
            : ImagePicker().pickVideo(source: ImageSource.gallery);
    final file = await pickFn();
    if (!mounted) return;
    setState(() {
      _picked = file;
      _pickAttempted = true;
    });
  }

  Future<void> _post() async {
    if (_picked == null) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await context.read<PostsViewModel>().createPost(
            type: widget.type,
            caption:
                _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
            authorUserId: widget.authorUserId,
            authorName: widget.authorName,
            mediaFile: File(_picked!.path),
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
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == PostType.photo ? 'New photo post' : 'New video post'),
      ),
      body: !_pickAttempted
          ? const Center(child: CircularProgressIndicator())
          : _picked == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No file selected'),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _pick, child: const Text('Choose again')),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.type == PostType.photo)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(_picked!.path),
                            height: 200,
                            fit: BoxFit.cover,
                            // A real device photo always resolves, but this
                            // guards against a picked-then-deleted file — and
                            // keeps widget tests deterministic, since a test's
                            // injected `pickFile` returns a path that doesn't
                            // exist on the test-running machine.
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 200,
                              color: Theme.of(context).colorScheme.surface,
                              child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(child: Icon(Icons.videocam, size: 48)),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _captionController,
                        decoration: const InputDecoration(hintText: 'Write a caption...'),
                        maxLines: 3,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _posting ? null : _post,
                        child: _posting
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Post'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
