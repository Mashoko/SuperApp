// Dev-only entry for visual checks of the KYC screens. Not imported by the
// app. Renders one screen in one state with an in-memory KycService, chosen
// by URL query parameters:
//
//   flutter build web -t tool/kyc_preview/main.dart --release
//
// The KYC views import core/di/inject.dart, which pulls in sip_ua. sip_ua
// 1.1.0 does not compile for the web against package:web 1.1.x
// (websocket_web_impl.dart passes a String where JSAny is expected). Build
// from a copy of the project with a pubspec_overrides.yaml pointing sip_ua
// at a local copy patched to `WebSocket(_url, 'sip'.toJS)`.
//
//   ?screen=form&step=0..4          form steps (complete draft, ID uploaded)
//   ?screen=form&step=0&draft=empty  empty draft with validation errors shown
//   ?screen=form&locked=1           read-only form (under review)
//   ?screen=status&state=REJECTED   status page; any KYC status string
//   ?screen=mandatory               restricted account screen
//   ?screen=emergency               emergency numbers sheet over mandatory
//   ?screen=reminder                reminder sheet over a placeholder home
//   ?screen=notifications           Updates list
//   ?screen=banner&state=IN_PROGRESS  home banner
//   &theme=dark                     dark theme (default light)
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_service.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_form_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_form_viewmodel.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_notifications_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_controller.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/mandatory_kyc_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/widgets/kyc_banner.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/widgets/kyc_emergency_sheet.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/widgets/kyc_reminder_sheet.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAGCAIAAABxZ0isAAAAEUlEQVR4nGOYNnsBVsQwkBIAiz1XMZ8M27wAAAAASUVORK5CYII=');

const _completeDraft = {
  'personal': {
    'firstName': 'Tendai',
    'lastName': 'Moyo',
    'dateOfBirth': '1990-05-04',
    'gender': 'female',
    'nationality': 'Zimbabwean',
  },
  'address': {
    'line1': '12 Samora Machel Ave',
    'city': 'Harare',
    'country': 'Zimbabwe',
  },
  'identification': {
    'idType': 'national_id',
    'idNumberMasked': '*********A42',
    'idExpiry': '2031-01-31',
  },
};

KycStatus _status(String state, {bool emptyDraft = false}) {
  final deadline = DateTime.now().toUtc().add(const Duration(days: 12));
  return KycStatus.fromJson({
    'status': state,
    'underlyingStatus': state == 'RESTRICTED' ? 'IN_PROGRESS' : state,
    'launched': true,
    'outstanding': state == 'APPROVED' || state == 'PENDING_REVIEW'
        ? const <String>[]
        : const ['documents.id_back', 'address.city'],
    'draft': emptyDraft ? const <String, dynamic>{} : _completeDraft,
    'documents': emptyDraft
        ? const <Map<String, dynamic>>[]
        : const [
            {
              'id': 'doc-front',
              'kind': 'id_front',
              'mime': 'image/png',
              'size': 84000
            },
            {
              'id': 'doc-back',
              'kind': 'id_back',
              'mime': 'application/pdf',
              'size': 212000
            },
          ],
    'phone': '263771234567',
    'deadline': deadline.toIso8601String(),
    'progress': state == 'NOT_STARTED' ? 0 : 60,
    'history': state == 'REJECTED' || state == 'REQUIRES_CORRECTION'
        ? [
            {
              'version': 1,
              'submittedAt': '2026-11-10T09:00:00Z',
              'decision':
                  state == 'REJECTED' ? 'rejected' : 'correction_requested',
              'decidedAt': '2026-11-12T14:30:00Z',
              'reason': 'The photo of the back of your ID is blurred.',
            }
          ]
        : const <Map<String, dynamic>>[],
    if (state == 'REJECTED')
      'rejectionReason': 'The photo of the back of your ID is blurred.',
    if (state == 'REQUIRES_CORRECTION')
      'correctionNotes': 'Check the spelling of your street address.',
  });
}

KycNotification _note(String id, String kind, String title, String body,
        {bool read = false, int daysAgo = 0}) =>
    KycNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      createdAt: DateTime.now().toUtc().subtract(Duration(days: daysAgo)),
      readAt: read ? DateTime.now().toUtc() : null,
    );

/// In-memory service: every call succeeds against fixed data.
class _PreviewService implements KycService {
  _PreviewService(this.status);

  KycStatus status;

  @override
  Future<KycStatus> getStatus() async => status;

  @override
  Future<void> saveDraft(KycDraft draft) async {}

  @override
  Future<KycDocumentInfo> uploadDocument({
    required String kind,
    required List<int> bytes,
    required String filename,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(1);
    return KycDocumentInfo(
        id: 'new-$kind', kind: kind, mime: 'image/png', size: bytes.length);
  }

  @override
  Future<void> deleteDocument(String id) async {}

  @override
  Future<Uint8List> fetchDocument(String id) async => _png;

  @override
  Future<void> submit() async {}

  @override
  Future<KycNotificationPage> listNotifications({int page = 1}) async => (
        items: [
          _note('n3', 'REMINDER_2', 'Finish verifying your account',
              'You have 12 days left to finish. It takes about five minutes.'),
          _note('n2', 'CORRECTION_REQUESTED', 'One detail needs a correction',
              'Check the spelling of your street address and submit again.',
              daysAgo: 3),
          _note('n1', 'status', 'We received your details',
              'Thanks. We will review them within two working days.',
              read: true, daysAgo: 9),
        ],
        unread: 2,
        totalPages: 1,
      );

  @override
  Future<void> markRead(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final screen = q['screen'] ?? 'status';
  final dark = q['theme'] == 'dark';
  final state = q['state'] ??
      switch (screen) {
        'mandatory' || 'emergency' => 'RESTRICTED',
        'form' => q['locked'] == '1' ? 'PENDING_REVIEW' : 'IN_PROGRESS',
        _ => 'IN_PROGRESS',
      };

  final service =
      _PreviewService(_status(state, emptyDraft: q['draft'] == 'empty'));
  final controller = KycStatusController(service);
  getIt
    ..registerSingleton<KycService>(service)
    ..registerSingleton<KycStatusController>(controller);
  await controller.refresh();

  Widget home;
  switch (screen) {
    case 'form':
      final vm = KycFormViewModel(service, controller);
      await vm.load();
      vm.goToStep(int.tryParse(q['step'] ?? '0') ?? 0);
      if (q['draft'] == 'empty') vm.next();
      home = KycFormView(viewModel: vm);
    case 'mandatory':
      home = _mandatory();
    case 'emergency':
      home = _OnFirstFrame(action: showKycEmergencySheet, child: _mandatory());
    case 'reminder':
      home = KycReminderHost(service: service, child: const _Home());
    case 'notifications':
      home = KycNotificationsView(service: service);
    case 'banner':
      home = const _Home();
    default:
      home = const KycStatusView();
  }

  runApp(ChangeNotifierProvider<KycStatusController>.value(
    value: controller,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: WunzaTheme.lightTheme,
      darkTheme: WunzaTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: home,
    ),
  ));
}

Widget _mandatory() => MandatoryKycView(
      onCompleteNow: () {},
      onContactSupport: () {},
      onSignOut: () {},
    );

/// Stand-in for the home tab so the banner and reminder have a page.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Home (preview)')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            KycBanner(),
            SizedBox(height: 16),
            Text('[Preview placeholder for the home feed]'),
          ],
        ),
      );
}

class _OnFirstFrame extends StatefulWidget {
  const _OnFirstFrame({required this.action, required this.child});

  final Future<void> Function(BuildContext) action;
  final Widget child;

  @override
  State<_OnFirstFrame> createState() => _OnFirstFrameState();
}

class _OnFirstFrameState extends State<_OnFirstFrame> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.action(context));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
