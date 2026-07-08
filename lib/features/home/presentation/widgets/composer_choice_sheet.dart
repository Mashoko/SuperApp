import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/models/post.dart';

class ComposerChoiceSheet extends StatelessWidget {
  const ComposerChoiceSheet({super.key, required this.onChoice});

  final ValueChanged<PostType> onChoice;

  static Future<void> show(BuildContext context, ValueChanged<PostType> onChoice) {
    return showModalBottomSheet(
      context: context,
      builder: (_) => ComposerChoiceSheet(onChoice: onChoice),
    );
  }

  void _choose(BuildContext context, PostType type) {
    Navigator.pop(context);
    onChoice(type);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _ChoiceTile(
            icon: Icons.image_outlined,
            label: 'Photo',
            onTap: () => _choose(context, PostType.photo),
          ),
          _ChoiceTile(
            icon: Icons.videocam_outlined,
            label: 'Video',
            onTap: () => _choose(context, PostType.video),
          ),
          _ChoiceTile(
            icon: Icons.text_fields,
            label: 'Text',
            onTap: () => _choose(context, PostType.text),
          ),
          _ChoiceTile(
            icon: Icons.mic_outlined,
            label: 'Audio',
            onTap: () => _choose(context, PostType.audio),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
  }
}
