import 'dart:async';
import 'dart:typed_data';

import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_service.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_status_controller.dart';

KycStatus kycStatus({
  Map<String, dynamic>? draft,
  List<Map<String, dynamic>> documents = const [],
  List<String> outstanding = const [],
  String status = 'IN_PROGRESS',
  String? underlyingStatus,
  bool launched = true,
  String? deadline,
  int progress = 0,
  List<Map<String, dynamic>> history = const [],
  String? rejectionReason,
  String? correctionNotes,
}) =>
    KycStatus.fromJson({
      'status': status,
      'underlyingStatus': underlyingStatus ?? status,
      'launched': launched,
      'outstanding': outstanding,
      'draft': draft ?? const {},
      'documents': documents,
      'phone': '263770000000',
      if (deadline != null) 'deadline': deadline,
      'progress': progress,
      'history': history,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (correctionNotes != null) 'correctionNotes': correctionNotes,
    });

KycNotification kycNote(String id,
        {bool read = false,
        String title = 'Update',
        String body = 'Your details changed.'}) =>
    KycNotification(
      id: id,
      kind: 'status',
      title: title,
      body: body,
      createdAt: DateTime.utc(2026, 11, 20, 10),
      readAt: read ? DateTime.utc(2026, 11, 21) : null,
    );

/// A draft that passes every step for a national ID holder.
const completeDraft = {
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
  },
};

Map<String, dynamic> docJson(String kind, {String? id, String mime = 'image/jpeg'}) => {
      'id': id ?? 'doc-$kind',
      'kind': kind,
      'mime': mime,
      'size': 1000,
    };

class FakeKycService implements KycService {
  final saved = <KycDraft>[];
  Object? saveError;
  Completer<void>? saveGate;

  int uploads = 0;
  Object? uploadError;
  Completer<KycDocumentInfo>? uploadGate;
  final progress = <double>[];

  final deleted = <String>[];
  Object? deleteError;

  int submits = 0;
  Object? submitError;

  Object? fetchError;

  /// Returned by [getStatus]; when null, [getStatus] throws.
  KycStatus? statusResult;
  Completer<void>? statusGate;
  int statusCalls = 0;

  @override
  Future<KycStatus> getStatus() async {
    statusCalls++;
    if (statusGate != null) await statusGate!.future;
    final result = statusResult;
    if (result == null) throw KycApiException(0, 'You are offline.');
    return result;
  }

  /// Notification pages keyed by page number. A missing page is empty.
  final notificationPages = <int, KycNotificationPage>{};
  final listCalls = <int>[];
  Object? listError;
  Completer<void>? listGate;

  /// Per-page gates, checked after [listGate].
  final pageGates = <int, Completer<void>>{};
  final markReadCalls = <String>[];
  Object? markReadError;
  Completer<void>? markReadGate;

  @override
  Future<KycNotificationPage> listNotifications({int page = 1}) async {
    listCalls.add(page);
    if (listGate != null) await listGate!.future;
    final pageGate = pageGates[page];
    if (pageGate != null) await pageGate.future;
    if (listError != null) throw listError!;
    return notificationPages[page] ??
        (items: <KycNotification>[], unread: 0, totalPages: 1);
  }

  @override
  Future<void> markRead(String id) async {
    markReadCalls.add(id);
    if (markReadGate != null) await markReadGate!.future;
    if (markReadError != null) throw markReadError!;
  }

  @override
  Future<void> saveDraft(KycDraft draft) async {
    saved.add(draft);
    if (saveGate != null) await saveGate!.future;
    if (saveError != null) throw saveError!;
  }

  @override
  Future<KycDocumentInfo> uploadDocument({
    required String kind,
    required List<int> bytes,
    required String filename,
    void Function(double)? onProgress,
  }) async {
    uploads++;
    onProgress?.call(0.0);
    if (uploadGate != null) return uploadGate!.future;
    if (uploadError != null) throw uploadError!;
    onProgress?.call(1.0);
    return KycDocumentInfo(
        id: 'new-$kind-$uploads', kind: kind, mime: 'image/jpeg', size: bytes.length);
  }

  @override
  Future<void> deleteDocument(String id) async {
    if (deleteError != null) throw deleteError!;
    deleted.add(id);
  }

  @override
  Future<Uint8List> fetchDocument(String id) async {
    if (fetchError != null) throw fetchError!;
    return Uint8List(0);
  }

  @override
  Future<void> submit() async {
    submits++;
    if (submitError != null) throw submitError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopService implements KycService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeKycController extends KycStatusController {
  FakeKycController(KycStatus? initial) : super(_NoopService()) {
    status = initial;
  }

  int refreshCalls = 0;
  int applySubmittedCalls = 0;
  KycStatus? next;
  String? failWith;
  bool _gone = false;

  @override
  Future<void> refresh() async {
    if (_gone) return;
    refreshCalls++;
    // Mirrors the real controller: with no status yet it sets `loading` and
    // notifies synchronously, before its first await. Results arrive after.
    if (status == null) {
      loading = true;
      notifyListeners();
    }
    await Future<void>.value();
    if (_gone) return;
    loading = false;
    if (failWith != null) {
      error = failWith;
      notifyListeners();
      return;
    }
    if (next != null) status = next;
    error = null;
    notifyListeners();
  }

  /// Counts, then behaves like the real controller: PENDING_REVIEW locally
  /// until a later successful refresh replaces it.
  @override
  void applySubmitted() {
    if (_gone) return;
    applySubmittedCalls++;
    super.applySubmitted();
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}
