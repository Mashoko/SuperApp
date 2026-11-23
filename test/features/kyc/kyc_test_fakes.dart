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
}) =>
    KycStatus.fromJson({
      'status': status,
      'underlyingStatus': status,
      'launched': true,
      'outstanding': outstanding,
      'draft': draft ?? const {},
      'documents': documents,
      'phone': '263771234567',
    });

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
  KycStatus? next;
  String? failWith;
  bool _gone = false;

  @override
  Future<void> refresh() async {
    if (_gone) return;
    refreshCalls++;
    if (failWith != null) {
      error = failWith;
      notifyListeners();
      return;
    }
    if (next != null) status = next;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}
