import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/kyc_models.dart';
import '../data/kyc_service.dart';
import '../domain/kyc_validation.dart';
import 'kyc_status_controller.dart';

enum KycSaveState { idle, saving, saved, error }

const kycMaxUploadBytes = 8 * 1024 * 1024;
const kycStepCount = 5;
const kycReviewStep = 4;

const _autosaveDelay = Duration(milliseconds: 800);
const _fallbackMessage = 'Something went wrong. Please try again.';
const _tooLargeMessage = 'This file is too large. Use a file under 8 MB.';
const _notSavedMessage = 'Not saved. Check your connection.';
const _staleMessage =
    'Could not load your latest details. Showing what was saved earlier.';
const _proofKey = 'documents.proof_of_residence';

/// Server limits for draft text fields (backend/kyc/validation.js
/// DRAFT_FIELDS).
const kycMaxLengths = <String, int>{
  'personal.firstName': 60,
  'personal.lastName': 60,
  'personal.nationality': 56,
  'address.line1': 120,
  'address.line2': 120,
  'address.city': 60,
  'address.country': 56,
  'identification.idNumber': 20,
};

class KycPickedFile {
  const KycPickedFile({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  bool get isPdf => filename.toLowerCase().endsWith('.pdf');
}

/// A tile's upload in progress, or its failure.
class KycUploadState {
  const KycUploadState.uploading(this.progress)
      : error = null,
        retryable = false;
  const KycUploadState.failed(this.error, {required this.retryable})
      : progress = 0;

  final double progress;
  final String? error;

  /// False when the same file would fail again (too large, wrong type).
  final bool retryable;

  bool get uploading => error == null;
}

class KycFormViewModel extends ChangeNotifier {
  KycFormViewModel(this._service, this._controller);

  final KycService _service;
  final KycStatusController _controller;

  // Load state
  bool loading = true;
  String? loadError;

  /// Set when the refresh failed and the form shows the cached status.
  String? staleNotice;

  /// `PENDING_REVIEW` or `APPROVED` when the record cannot be edited; the
  /// view shows a read-only state and nothing is saved.
  String? lockedStatus;
  bool get readOnly => lockedStatus != null;

  // Form state
  int step = 0;
  String phone = '';
  String? firstName;
  String? lastName;
  DateTime? dateOfBirth;
  String? gender;
  String? nationality;
  String? line1;
  String? line2;
  String? city;
  String? country;
  String? idType;
  String? idNumberMasked;
  String? newIdNumber;
  DateTime? idExpiry;

  Map<String, String> errors = {};

  // Documents
  List<KycDocumentInfo> documents = [];
  final Map<String, KycUploadState> uploads = {};
  final Map<String, Uint8List> localPreviews = {};
  final Set<String> localPdfs = {};
  final Map<String, String> documentErrors = {};
  final Map<String, KycPickedFile> _pendingFiles = {};
  final Map<String, Future<Uint8List?>> _previewCache = {};
  /// Once proof of residence is shown it stays for the session.
  bool _proofSticky = false;

  // The ID number held on the server belongs to the ID type it was saved
  // with; switching type hides it until the user switches back.
  String? _loadedIdType;
  String? _loadedMasked;

  /// True once anything was written to the server, so leaving refreshes the
  /// app-wide status.
  bool _changed = false;

  // Autosave
  KycSaveState saveState = KycSaveState.idle;
  Timer? _timer;
  bool _dirty = false;
  Future<void>? _saving;

  /// The reason for [KycSaveState.error] when it is not a connection
  /// problem; null means "Not saved. Check your connection.".
  String? saveError;

  // Submit
  bool submitting = false;
  bool submitted = false;
  String? submitError;

  bool _disposed = false;

  /// Always refreshes so the form never starts from a stale draft (a stale
  /// draft would be autosaved back over newer server data). Falls back to the
  /// cached status, with [staleNotice], only when the refresh fails.
  Future<void> load() async {
    loading = true;
    loadError = null;
    staleNotice = null;
    _notify();
    await _controller.refresh();
    if (_disposed) return;
    final status = _controller.status;
    if (status == null) {
      loadError = _controller.error ?? _fallbackMessage;
      loading = false;
      _notify();
      return;
    }
    if (_controller.error != null) staleNotice = _staleMessage;
    if (!status.canEdit) {
      lockedStatus = status.isVerified ? 'APPROVED' : 'PENDING_REVIEW';
    } else {
      lockedStatus = null;
      _apply(status);
    }
    loading = false;
    _notify();
  }

  void _apply(KycStatus status) {
    final d = status.draft;
    phone = status.phone;
    firstName = d.personal.firstName;
    lastName = d.personal.lastName;
    dateOfBirth = d.personal.dateOfBirth;
    gender = d.personal.gender;
    nationality = d.personal.nationality;
    line1 = d.address.line1;
    line2 = d.address.line2;
    city = d.address.city;
    country = d.address.country;
    idType = d.identification.idType;
    idNumberMasked = d.identification.idNumberMasked;
    newIdNumber = null;
    idExpiry = d.identification.idExpiry;
    documents = List.of(status.documents);
    _loadedIdType = idType;
    _loadedMasked = idNumberMasked;
    _proofSticky = status.outstanding.contains(_proofKey) ||
        documents.any((d) => d.kind == 'proof_of_residence');
  }

  // --- Fields ---------------------------------------------------------------

  void setFirstName(String v) => _edit('personal.firstName', () => firstName = v);
  void setLastName(String v) => _edit('personal.lastName', () => lastName = v);
  void setDateOfBirth(DateTime v) => _edit(
      'personal.dateOfBirth', () => dateOfBirth = DateTime.utc(v.year, v.month, v.day));
  void setGender(String v) => _edit('personal.gender', () => gender = v);
  void setNationality(String v) =>
      _edit('personal.nationality', () => nationality = v);
  void setLine1(String v) => _edit('address.line1', () => line1 = v);
  void setLine2(String v) => _edit('address.line2', () => line2 = v);
  void setCity(String v) => _edit('address.city', () => city = v);
  void setCountry(String v) => _edit('address.country', () => country = v);
  void setIdNumber(String v) =>
      _edit('identification.idNumber', () => newIdNumber = v);
  void setIdExpiry(DateTime v) => _edit('identification.idExpiry',
      () => idExpiry = DateTime.utc(v.year, v.month, v.day));

  void setIdType(String v) {
    if (v == idType) return;
    errors.remove('identification.idNumber');
    errors.removeWhere((k, _) => k.startsWith('documents.') && k != _proofKey);
    // A number saved for another ID type cannot be reused: require a new one.
    idNumberMasked = v == _loadedIdType ? _loadedMasked : null;
    _edit('identification.idType', () => idType = v);
  }

  void _edit(String key, void Function() apply) {
    if (readOnly) return;
    apply();
    errors.remove(key);
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(_autosaveDelay, () => unawaited(_save()));
    _notify();
  }

  KycDraft get draft => KycDraft(
        personal: KycPersonal(
          firstName: firstName?.trim(),
          lastName: lastName?.trim(),
          dateOfBirth: dateOfBirth,
          gender: gender,
          nationality: nationality?.trim(),
        ),
        address: KycAddress(
          line1: line1?.trim(),
          line2: line2?.trim(),
          city: city?.trim(),
          country: country?.trim(),
        ),
        identification: KycIdentification(
          idType: idType,
          idNumberMasked: idNumberMasked,
          newIdNumber: newIdNumber,
          idExpiry: idExpiry,
        ),
      );

  // --- Autosave -------------------------------------------------------------

  Future<void> retrySave() {
    _dirty = true;
    return _save();
  }

  /// Saves now, after any save in flight. Edits made during a save restart
  /// the debounce timer, which saves them next.
  Future<void> _save() async {
    _timer?.cancel();
    while (_saving != null) {
      await _saving;
    }
    if (!_dirty) return;
    _dirty = false;
    saveState = KycSaveState.saving;
    _notify();
    final run = _send(draft);
    _saving = run;
    await run;
    _saving = null;
  }

  Future<void> _send(KycDraft d) async {
    try {
      await _service.saveDraft(d);
      _changed = true;
      saveState = KycSaveState.saved;
      saveError = null;
    } on KycValidationException catch (e) {
      _dirty = true;
      errors.addAll(e.errors);
      saveState = KycSaveState.error;
      saveError = e.message;
    } on KycApiException catch (e) {
      _dirty = true;
      saveState = KycSaveState.error;
      // Status 0 is "no connection" from KycService.
      saveError = e.statusCode == 0 ? null : e.message;
    } catch (_) {
      _dirty = true;
      saveState = KycSaveState.error;
      saveError = _fallbackMessage;
    }
    _notify();
  }

  // --- Steps ----------------------------------------------------------------

  Map<String, String> _validate() {
    final e = validateKyc(
      draft,
      documents: documents,
      requireProofOfResidence: _proofSticky,
    );
    if (idType == 'passport' && e['identification.idNumber'] == 'Enter your ID number.') {
      e['identification.idNumber'] = 'Enter your passport number.';
    }
    return e;
  }

  /// Validates the current step. Returns false and shows errors if it fails.
  bool next() {
    if (step >= kycReviewStep) return false;
    final stepErrors = errorsForStep(_validate(), step);
    errors.removeWhere((k, _) => kycStepForKey(k) == step);
    if (stepErrors.isNotEmpty) {
      errors.addAll(stepErrors);
      _notify();
      return false;
    }
    goToStep(step + 1);
    return true;
  }

  void back() {
    if (step > 0) goToStep(step - 1);
  }

  void goToStep(int s) {
    final target = s.clamp(0, kycReviewStep);
    if (target == step) return;
    step = target;
    submitError = null;
    if (_dirty || _timer?.isActive == true) unawaited(_save());
    _notify();
  }

  // --- Documents ------------------------------------------------------------

  bool get showProofOfResidence => _proofSticky;

  List<String> get documentKinds => [
        ...requiredDocumentKinds(idType),
        if (showProofOfResidence) 'proof_of_residence',
      ];

  KycDocumentInfo? documentFor(String kind) {
    for (final d in documents.reversed) {
      if (d.kind == kind) return d;
    }
    return null;
  }

  Future<void> upload(String kind, KycPickedFile file) async {
    documentErrors.remove(kind);
    errors.remove('documents.$kind');
    if (file.bytes.length > kycMaxUploadBytes) {
      uploads[kind] =
          const KycUploadState.failed(_tooLargeMessage, retryable: false);
      _notify();
      return;
    }
    _pendingFiles[kind] = file;
    uploads[kind] = const KycUploadState.uploading(0);
    _notify();
    try {
      final doc = await _service.uploadDocument(
        kind: kind,
        bytes: file.bytes,
        filename: file.filename,
        onProgress: (p) {
          if (uploads[kind]?.uploading != true) return;
          uploads[kind] = KycUploadState.uploading(p);
          _notify();
        },
      );
      _changed = true;
      documents = [
        ...documents.where((d) => d.kind != kind),
        doc,
      ];
      uploads.remove(kind);
      _pendingFiles.remove(kind);
      if (file.isPdf) {
        localPdfs.add(kind);
        localPreviews.remove(kind);
      } else {
        localPdfs.remove(kind);
        localPreviews[kind] = file.bytes;
      }
    } on KycApiException catch (e) {
      final retryable = e.statusCode != 413 && e.statusCode != 415;
      uploads[kind] = KycUploadState.failed(e.message, retryable: retryable);
    } catch (_) {
      uploads[kind] =
          const KycUploadState.failed(_fallbackMessage, retryable: true);
    }
    _notify();
  }

  Future<void> retryUpload(String kind) async {
    final file = _pendingFiles[kind];
    if (file != null) await upload(kind, file);
  }

  Future<void> remove(String documentId) async {
    final doc = documents.where((d) => d.id == documentId).firstOrNull;
    if (doc == null) return;
    documentErrors.remove(doc.kind);
    _notify();
    try {
      await _service.deleteDocument(documentId);
      _changed = true;
      documents = documents.where((d) => d.id != documentId).toList();
      localPreviews.remove(doc.kind);
      localPdfs.remove(doc.kind);
      _previewCache.remove(documentId);
    } on KycApiException catch (e) {
      documentErrors[doc.kind] = e.message;
    } catch (_) {
      documentErrors[doc.kind] = _fallbackMessage;
    }
    _notify();
  }

  /// Thumbnail bytes for an image already on the server, or null when it
  /// cannot be shown.
  Future<Uint8List?> preview(KycDocumentInfo doc) {
    return _previewCache[doc.id] ??= () async {
      try {
        final bytes = await _service.fetchDocument(doc.id);
        return bytes.isEmpty ? null : bytes;
      } catch (_) {
        _previewCache.remove(doc.id);
        return null;
      }
    }();
  }

  // --- Submit ---------------------------------------------------------------

  Future<void> submit() async {
    if (submitting || submitted) return;
    submitError = null;
    final clientErrors = _validate();
    if (clientErrors.isNotEmpty) {
      _showErrors(clientErrors);
      return;
    }
    submitting = true;
    _notify();
    try {
      await _save();
      if (saveState == KycSaveState.error) {
        submitError = saveError ?? _notSavedMessage;
        return;
      }
      await _service.submit();
      await _controller.refresh();
      submitted = true;
    } on KycValidationException catch (e) {
      _showErrors(e.errors, message: e.message);
    } on KycApiException catch (e) {
      submitError = e.message;
    } catch (_) {
      submitError = _fallbackMessage;
    } finally {
      submitting = false;
      _notify();
    }
  }

  void _showErrors(Map<String, String> all, {String? message}) {
    errors = Map.of(all);
    if (all.containsKey(_proofKey)) _proofSticky = true;
    final first = all.keys.map(kycStepForKey).fold(kycReviewStep,
        (int a, int b) => a < b ? a : b);
    if (first == kycReviewStep) submitError = message ?? _fallbackMessage;
    goToStep(first);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    // Keep the last edit. The server's draft PUT is an unlocked
    // read-merge-write, so this save must start only after any save in flight
    // or that older save could land last. Then refresh the app-wide status so
    // the next open (and the gate) sees what was saved.
    final prior = _saving ?? Future<void>.value();
    if (_dirty && !readOnly) {
      final snapshot = draft;
      _dirty = false;
      unawaited(prior
          .then((_) => _service.saveDraft(snapshot))
          .then((_) {}, onError: (Object _) {})
          .then((_) => _controller.refresh()));
    } else if (_changed || _saving != null) {
      unawaited(prior.then((_) => _controller.refresh()));
    }
    super.dispose();
  }
}
