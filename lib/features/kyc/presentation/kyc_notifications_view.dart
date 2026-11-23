import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/inject.dart';
import '../data/kyc_models.dart';
import '../data/kyc_service.dart';
import 'kyc_labels.dart';
import 'kyc_theme.dart';

const _fallbackMessage = 'Something went wrong. Please try again.';

String _messageFor(Object e) =>
    e is KycApiException && e.message.isNotEmpty ? e.message : _fallbackMessage;

KycNotification _withReadAt(KycNotification n, DateTime? readAt) =>
    KycNotification(
      id: n.id,
      kind: n.kind,
      title: n.title,
      body: n.body,
      createdAt: n.createdAt,
      readAt: readAt,
    );

/// Paginated KYC updates. Tapping an unread update marks it read.
class KycNotificationsView extends StatefulWidget {
  const KycNotificationsView({super.key, this.service});

  /// For tests. Defaults to the registered [KycService].
  final KycService? service;

  @override
  State<KycNotificationsView> createState() => _KycNotificationsViewState();
}

class _KycNotificationsViewState extends State<KycNotificationsView> {
  late final KycService _service = widget.service ?? getIt<KycService>();

  List<KycNotification> _items = const [];
  int _page = 0;
  int _totalPages = 0;
  bool _loading = true;
  String? _error;
  bool _loadingMore = false;
  String? _moreError;
  int _generation = 0;

  bool get _hasMore => _page < _totalPages;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFirst());
  }

  Future<void> _loadFirst({bool spinner = true}) async {
    final gen = ++_generation;
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await _service.listNotifications(page: 1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items = [...page.items];
        _page = 1;
        _totalPages = page.totalPages;
        _loading = false;
        _error = null;
        _loadingMore = false;
        _moreError = null;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      final message = _messageFor(e);
      setState(() {
        _loading = false;
        // A load-more dropped by this refresh must not leave the footer
        // spinning; the footer starts it again.
        _loadingMore = false;
        if (_items.isEmpty) _error = message;
      });
      if (_items.isNotEmpty) _showSnack(message);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _moreError != null || !_hasMore) return;
    final gen = _generation;
    final next = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.listNotifications(page: next);
      if (!mounted || gen != _generation) return;
      final known = {for (final n in _items) n.id};
      setState(() {
        _items = [
          ..._items,
          for (final n in page.items)
            if (!known.contains(n.id)) n,
        ];
        _page = next;
        _totalPages = page.totalPages;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loadingMore = false;
        _moreError = _messageFor(e);
      });
    }
  }

  void _retryMore() {
    setState(() => _moreError = null);
    unawaited(_loadMore());
  }

  void _replace(String id, KycNotification Function(KycNotification) change) {
    setState(() {
      _items = [for (final n in _items) n.id == id ? change(n) : n];
    });
  }

  Future<void> _markRead(KycNotification n) async {
    if (n.isRead) return;
    _replace(n.id, (cur) => _withReadAt(cur, DateTime.now().toUtc()));
    try {
      await _service.markRead(n.id);
    } catch (_) {
      if (!mounted) return;
      _replace(n.id, (cur) => _withReadAt(cur, null));
      _showSnack('Could not mark this update as read. Please try again.');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = kycTheme(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(title: const Text('Updates')),
        body: Builder(builder: _body),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return KycMessage(
        icon: Icons.cloud_off_outlined,
        text: _error!,
        action: FilledButton(
          onPressed: () => unawaited(_loadFirst()),
          child: const Text('Try again'),
        ),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return RefreshIndicator(
      onRefresh: () => _loadFirst(spinner: false),
      child: LayoutBuilder(builder: (context, constraints) {
        final side = ((constraints.maxWidth - kycMaxContentWidth) / 2)
            .clamp(0.0, double.infinity);
        if (_items.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side + 16, 64, side + 16, 32),
            children: [
              Icon(Icons.notifications_none,
                  size: 40, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No updates yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18)),
            ],
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, 8, side, 32),
          itemCount: _items.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, __) =>
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          itemBuilder: (context, i) {
            if (i < _items.length) {
              final n = _items[i];
              return _NotificationTile(
                  notification: n, onTap: () => unawaited(_markRead(n)));
            }
            return _footer(context);
          },
        );
      }),
    );
  }

  Widget _footer(BuildContext context) {
    final theme = Theme.of(context);
    if (_moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(_moreError!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _retryMore, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (!_loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadMore());
      });
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final KycNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = !notification.isRead;
    final created = notification.createdAt;
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 10,
                child: unread
                    ? Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Semantics(
                          label: 'Unread',
                          child: Container(
                            key: const ValueKey('kyc-unread-dot'),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: scheme.primary, shape: BoxShape.circle),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title,
                        style: body?.copyWith(
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w500)),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(notification.body,
                          style:
                              body?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                    if (created != null) ...[
                      const SizedBox(height: 6),
                      Text(kycLocalDate(created),
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14, color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
