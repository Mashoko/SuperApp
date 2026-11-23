import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/kyc_models.dart';
import '../kyc_form_viewmodel.dart';

/// One required document: empty, uploading, failed or uploaded.
class KycDocumentTile extends StatelessWidget {
  const KycDocumentTile({
    super.key,
    required this.label,
    required this.document,
    required this.upload,
    required this.localPreview,
    required this.localIsPdf,
    required this.error,
    required this.loadPreview,
    required this.onPick,
    required this.onRetry,
    required this.onRemove,
  });

  final String label;
  final KycDocumentInfo? document;
  final KycUploadState? upload;
  final Uint8List? localPreview;
  final bool localIsPdf;

  /// A failed remove, shown under the tile.
  final String? error;
  final Future<Uint8List?> Function(KycDocumentInfo) loadPreview;
  final VoidCallback onPick;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16);
    final up = upload;
    final doc = document;
    final uploading = up != null && up.uploading;
    final failed = up != null && !up.uploading;

    final lines = <Widget>[];
    VoidCallback? onTap;
    if (uploading) {
      lines.add(Text('Uploading ${(up.progress * 100).round()}%',
          style: body?.copyWith(color: scheme.onSurfaceVariant)));
    } else if (failed && up.retryable) {
      onTap = onRetry;
      lines.add(Text('Upload failed. Tap to retry.',
          style: body?.copyWith(color: scheme.error)));
      lines.add(Text(up.error!, style: body?.copyWith(color: scheme.onSurfaceVariant)));
    } else if (failed) {
      onTap = onPick;
      lines.add(Text(up.error!, style: body?.copyWith(color: scheme.error)));
      lines.add(Text('Add photo or file',
          style: body?.copyWith(color: scheme.primary)));
    } else if (doc != null) {
      onTap = onPick;
      lines.add(Text('Uploaded. Tap to replace.',
          style: body?.copyWith(color: scheme.onSurfaceVariant)));
    } else {
      onTap = onPick;
      lines.add(Text('Add photo or file',
          style: body?.copyWith(color: scheme.primary)));
    }
    if (error != null) {
      lines.add(Text(error!, style: body?.copyWith(color: scheme.error)));
    }

    final radius = BorderRadius.circular(8);
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  children: [
                    _Thumb(
                      document: doc,
                      uploading: uploading,
                      localPreview: localPreview,
                      localIsPdf: localIsPdf,
                      loadPreview: loadPreview,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: body?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          ...lines,
                        ],
                      ),
                    ),
                    if (doc != null && !uploading)
                      IconButton(
                        tooltip: 'Remove $label',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onRemove,
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            if (uploading) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.document,
    required this.uploading,
    required this.localPreview,
    required this.localIsPdf,
    required this.loadPreview,
  });

  final KycDocumentInfo? document;
  final bool uploading;
  final Uint8List? localPreview;
  final bool localIsPdf;
  final Future<Uint8List?> Function(KycDocumentInfo) loadPreview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget icon(IconData data, {Color? color}) =>
        Icon(data, size: 28, color: color ?? scheme.onSurfaceVariant);
    Widget image(Uint8List bytes) => Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: 56,
          height: 56,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => icon(Icons.image_outlined),
        );

    final doc = document;
    Widget child;
    if (uploading) {
      child = const SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (doc == null) {
      child = icon(Icons.add_a_photo_outlined, color: scheme.primary);
    } else if (localPreview != null) {
      child = image(localPreview!);
    } else if (localIsPdf || doc.mime == 'application/pdf') {
      child = icon(Icons.picture_as_pdf_outlined);
    } else {
      child = FutureBuilder<Uint8List?>(
        future: loadPreview(doc),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
          }
          final bytes = snap.data;
          return bytes == null ? icon(Icons.image_outlined) : image(bytes);
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      ),
    );
  }
}
