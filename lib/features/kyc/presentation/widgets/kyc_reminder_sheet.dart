import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/inject.dart';
import '../../data/kyc_models.dart';
import '../../data/kyc_service.dart';
import '../kyc_status_controller.dart';
import '../kyc_status_view.dart';
import '../kyc_theme.dart';

/// SharedPreferences key holding the ids of reminders the user closed.
const kycDismissedNotificationsKey = 'kyc_dismissed_notifications';
const _maxDismissed = 50;

/// Kinds that prompt the user to act. The server stores every
/// `REMINDER_<n>` stage as `REMINDER`; both forms are accepted.
const _reminderKinds = {
  'NUDGE_1',
  'NUDGE_2',
  'REMINDER',
  'WARNING',
  'CORRECTION_REQUESTED',
  'REJECTED',
  'EXPIRED',
};
final _reminderStage = RegExp(r'^REMINDER_\d+$');

bool isKycReminderKind(String kind) =>
    _reminderKinds.contains(kind) || _reminderStage.hasMatch(kind);

/// Ids already offered in this app session, so a reminder is shown at most
/// once per session even if it could not be recorded as dismissed.
final _shownThisSession = <String>{};

@visibleForTesting
void resetKycReminderSessionForTest() => _shownThisSession.clear();

enum _ReminderAction { continueNow, later }

/// Wraps the home screen. After the first frame, and whenever a new KYC
/// status loads, shows the newest unread reminder in a bottom sheet once.
/// Never shown before launch, while restricted (the gate covers that), or
/// once the record is submitted or approved.
class KycReminderHost extends StatefulWidget {
  const KycReminderHost({super.key, required this.child, this.service});

  final Widget child;

  /// For tests. Defaults to the registered [KycService].
  final KycService? service;

  @override
  State<KycReminderHost> createState() => _KycReminderHostState();
}

class _KycReminderHostState extends State<KycReminderHost> {
  KycStatusController? _controller;
  KycStatus? _lastStatus;
  bool _checking = false;

  KycService get _service => widget.service ?? getIt<KycService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<KycStatusController>();
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onStatusChanged);
      _controller = controller..addListener(_onStatusChanged);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    final status = _controller?.status;
    if (status == null || identical(status, _lastStatus)) return;
    unawaited(_check());
  }

  bool _eligible() {
    final controller = _controller;
    final status = controller?.status;
    if (controller == null || status == null || !mounted) return false;
    // Only while home is the visible page, never over a call or checkout.
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    return status.launched &&
        !controller.isRestricted &&
        !status.isVerified &&
        !status.isPendingReview;
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    final status = _controller?.status;
    if (status == null) return;
    if (!_eligible()) {
      // Covered by another page: try again on the next status load.
      if (ModalRoute.of(context)?.isCurrent != false) _lastStatus = status;
      return;
    }
    _lastStatus = status;
    _checking = true;
    try {
      final page = await _service.listNotifications();
      if (!mounted) return;
      final dismissed = (await _loadDismissed()).toSet();
      if (!mounted || !_eligible()) return;
      final candidates = page.items
          .where((n) =>
              !n.isRead &&
              isKycReminderKind(n.kind) &&
              !dismissed.contains(n.id) &&
              !_shownThisSession.contains(n.id))
          .toList()
        ..sort((a, b) {
          final ad = a.createdAt, bd = b.createdAt;
          if (ad == null || bd == null) return ad == null ? 1 : -1;
          return bd.compareTo(ad);
        });
      if (candidates.isEmpty) return;
      final note = candidates.first;
      _shownThisSession.add(note.id);
      await _show(note);
    } catch (_) {
      // Best effort: the reminder is a convenience, the banner remains.
    } finally {
      _checking = false;
    }
  }

  Future<void> _show(KycNotification note) async {
    final action = await showModalBottomSheet<_ReminderAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (_) => KycReminderSheet(notification: note),
    );
    // Closing the sheet any other way counts as "Later".
    unawaited(_markRead(note.id));
    await _recordDismissed(note.id);
    if (action == _ReminderAction.continueNow && mounted) {
      unawaited(Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const KycStatusView())));
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _service.markRead(id);
    } catch (_) {
      // Best effort; the Updates list still shows it as unread.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<List<String>> _loadDismissed() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(kycDismissedNotificationsKey) ?? const [];
  } catch (_) {
    return const [];
  }
}

Future<void> _recordDismissed(String id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final ids = [
      ...?prefs
          .getStringList(kycDismissedNotificationsKey)
          ?.where((e) => e != id),
      id,
    ];
    if (ids.length > _maxDismissed) {
      ids.removeRange(0, ids.length - _maxDismissed);
    }
    await prefs.setStringList(kycDismissedNotificationsKey, ids);
  } catch (_) {
    // The session set still prevents a repeat until the app restarts.
  }
}

/// The reminder's title and body with "Continue" (the primary action) and
/// "Later".
class KycReminderSheet extends StatelessWidget {
  const KycReminderSheet({super.key, required this.notification});

  final KycNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = kycTheme(Theme.of(context));
    final scheme = theme.colorScheme;
    return Theme(
      data: theme,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  notification.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notification.body,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontSize: 16, color: scheme.onSurface),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_ReminderAction.later),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_ReminderAction.continueNow),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
