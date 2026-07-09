import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/home/presentation/viewmodels/posts_viewmodel.dart';
import 'package:mvvm_sip_demo/models/post.dart';

class ComposerAudioView extends StatefulWidget {
  const ComposerAudioView({
    super.key,
    required this.authorUserId,
    required this.authorName,
    this.pickFile,
  });

  final String authorUserId;
  final String authorName;
  final Future<String?> Function()? pickFile;

  @override
  State<ComposerAudioView> createState() => _ComposerAudioViewState();
}

class _ComposerAudioViewState extends State<ComposerAudioView> {
  final _titleController = TextEditingController();
  String? _pickedPath;
  bool _posting = false;
  bool _pickAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final pickFn = widget.pickFile ?? _defaultPick;
    final path = await pickFn();
    if (!mounted) return;
    setState(() {
      _pickedPath = path;
      _pickAttempted = true;
    });
  }

  Future<String?> _defaultPick() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    return result?.files.single.path;
  }

  Future<void> _post() async {
    if (_pickedPath == null) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await context.read<PostsViewModel>().createPost(
            type: PostType.audio,
            audioTitle:
                _titleController.text.trim().isEmpty ? 'Untitled' : _titleController.text.trim(),
            authorUserId: widget.authorUserId,
            authorName: widget.authorName,
            mediaFile: File(_pickedPath!),
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
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New audio post')),
      body: !_pickAttempted
          ? const Center(child: CircularProgressIndicator())
          : _pickedPath == null
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
                      Text('Selected: ${_pickedPath!.split('/').last}'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(hintText: 'Title (e.g. Sunset drive mix)'),
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
