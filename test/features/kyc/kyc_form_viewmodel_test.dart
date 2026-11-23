import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_models.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_service.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_form_viewmodel.dart';

import 'kyc_test_fakes.dart';

KycPickedFile _file([int size = 10]) =>
    KycPickedFile(bytes: Uint8List(size), filename: 'front.jpg');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeKycService service;
  late FakeKycController controller;
  late KycFormViewModel vm;

  void build(KycStatus status) {
    controller = FakeKycController(status);
    vm = KycFormViewModel(service, controller);
  }

  setUp(() {
    service = FakeKycService();
  });

  tearDown(() {
    vm.dispose();
    controller.dispose();
  });

  group('load', () {
    test('loads fields from the controller draft and the phone', () async {
      build(kycStatus(draft: completeDraft, documents: [docJson('id_front')]));
      await vm.load();
      expect(vm.loading, isFalse);
      expect(vm.firstName, 'Tendai');
      expect(vm.dateOfBirth, DateTime.utc(1990, 5, 4));
      expect(vm.idType, 'national_id');
      expect(vm.idNumberMasked, '*********A42');
      expect(vm.newIdNumber, isNull);
      expect(vm.phone, '263771234567');
      expect(vm.documents.single.kind, 'id_front');
      expect(vm.step, 0);
    });

    test('refreshes when the controller has no status, error when it fails',
        () async {
      build(kycStatus());
      controller.status = null;
      controller.failWith = 'No connection. Check your internet and try again.';
      await vm.load();
      expect(vm.loadError, 'No connection. Check your internet and try again.');
      controller.failWith = null;
      controller.next = kycStatus(draft: completeDraft);
      await vm.load();
      expect(vm.loadError, isNull);
      expect(vm.firstName, 'Tendai');
    });

    test('proof of residence only when outstanding or already uploaded',
        () async {
      build(kycStatus(draft: completeDraft));
      await vm.load();
      expect(vm.documentKinds, ['id_front', 'id_back']);
      vm.dispose();
      controller.dispose();
      build(kycStatus(
          draft: completeDraft, outstanding: ['documents.proof_of_residence']));
      await vm.load();
      expect(vm.documentKinds, ['id_front', 'id_back', 'proof_of_residence']);
      vm.dispose();
      controller.dispose();
      build(kycStatus(
          draft: completeDraft, documents: [docJson('proof_of_residence')]));
      await vm.load();
      expect(vm.documentKinds, contains('proof_of_residence'));
    });
  });

  group('autosave', () {
    test('debounces 800 ms after the last edit', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        vm.load();
        async.flushMicrotasks();
        vm.setFirstName('T');
        async.elapse(const Duration(milliseconds: 500));
        vm.setFirstName('Ta');
        async.elapse(const Duration(milliseconds: 799));
        expect(service.saved, isEmpty);
        expect(vm.saveState, KycSaveState.idle);
        async.elapse(const Duration(milliseconds: 1));
        expect(service.saved, hasLength(1));
        expect(service.saved.single.personal.firstName, 'Ta');
        async.flushMicrotasks();
        expect(vm.saveState, KycSaveState.saved);
      });
    });

    test('shows saving while in flight and error when it fails', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        vm.load();
        async.flushMicrotasks();
        service.saveGate = Completer<void>();
        vm.setCity('Bulawayo');
        async.elapse(const Duration(milliseconds: 800));
        expect(vm.saveState, KycSaveState.saving);
        service.saveError = KycApiException(0, 'offline');
        service.saveGate!.complete();
        async.flushMicrotasks();
        expect(vm.saveState, KycSaveState.error);
        service.saveError = null;
        service.saveGate = null;
        vm.retrySave();
        async.flushMicrotasks();
        expect(vm.saveState, KycSaveState.saved);
        expect(service.saved.last.address.city, 'Bulawayo');
      });
    });

    test('saves immediately on step change', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        vm.load();
        async.flushMicrotasks();
        vm.setLastName('Ncube');
        expect(vm.next(), isTrue);
        async.flushMicrotasks();
        expect(service.saved, hasLength(1));
        expect(service.saved.single.personal.lastName, 'Ncube');
        expect(vm.step, 1);
        async.elapse(const Duration(seconds: 2));
        expect(service.saved, hasLength(1), reason: 'timer cancelled');
      });
    });

    test('clearing a text field sends an empty string', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        vm.load();
        async.flushMicrotasks();
        vm.setNationality('');
        async.elapse(const Duration(milliseconds: 800));
        expect(service.saved.single.toJson()['personal']['nationality'], '');
      });
    });

    test('ID number is only sent after the user types one', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        vm.load();
        async.flushMicrotasks();
        vm.setCity('Mutare');
        async.elapse(const Duration(milliseconds: 800));
        expect(
            service.saved.last.toJson()['identification'].containsKey('idNumber'),
            isFalse);
        vm.setIdNumber('63-123456-A-42');
        async.elapse(const Duration(milliseconds: 800));
        expect(service.saved.last.toJson()['identification']['idNumber'],
            '63-123456-A-42');
      });
    });
  });

  group('steps', () {
    test('next() is blocked with errors on the current step', () async {
      build(kycStatus());
      await vm.load();
      expect(vm.next(), isFalse);
      expect(vm.step, 0);
      expect(vm.errors['personal.firstName'], 'Enter your first name.');
      expect(vm.errors.keys.every((k) => k.startsWith('personal.')), isTrue);
      vm.setFirstName('Tendai');
      expect(vm.errors, isNot(contains('personal.firstName')),
          reason: 'editing clears that field error');
    });

    test('documents step blocks until required uploads exist', () async {
      build(kycStatus(draft: completeDraft));
      await vm.load();
      expect(vm.next(), isTrue);
      expect(vm.next(), isTrue);
      expect(vm.next(), isTrue);
      expect(vm.step, 3);
      expect(vm.next(), isFalse);
      expect(vm.errors.keys, containsAll(['documents.id_front', 'documents.id_back']));
      vm.back();
      expect(vm.step, 2);
    });
  });

  group('uploads', () {
    test('progress, then the document is added', () async {
      build(kycStatus(draft: completeDraft));
      await vm.load();
      service.uploadGate = Completer<KycDocumentInfo>();
      final f = vm.upload('id_front', _file());
      await Future<void>.delayed(Duration.zero);
      expect(vm.uploads['id_front']?.uploading, isTrue);
      expect(vm.uploads['id_front']?.progress, 0.0);
      service.uploadGate!.complete(const KycDocumentInfo(
          id: 'd1', kind: 'id_front', mime: 'image/jpeg', size: 10));
      await f;
      expect(vm.uploads, isNot(contains('id_front')));
      expect(vm.documentFor('id_front')?.id, 'd1');
      expect(vm.localPreviews['id_front'], isNotNull);
    });

    test('a new upload replaces the old document of that kind', () async {
      build(kycStatus(draft: completeDraft, documents: [docJson('id_front')]));
      await vm.load();
      await vm.upload('id_front', _file());
      expect(vm.documents.where((d) => d.kind == 'id_front'), hasLength(1));
      expect(vm.documentFor('id_front')?.id, startsWith('new-'));
    });

    test('failure keeps the draft and can be retried', () async {
      build(kycStatus(draft: completeDraft));
      await vm.load();
      vm.setCity('Gweru');
      service.uploadError = KycApiException(0, 'No connection.');
      await vm.upload('id_back', _file());
      final st = vm.uploads['id_back']!;
      expect(st.uploading, isFalse);
      expect(st.retryable, isTrue);
      expect(st.error, 'No connection.');
      expect(vm.city, 'Gweru');
      expect(vm.firstName, 'Tendai');
      service.uploadError = null;
      await vm.retryUpload('id_back');
      expect(service.uploads, 2);
      expect(vm.uploads, isNot(contains('id_back')));
      expect(vm.documentFor('id_back'), isNotNull);
    });

    test('files over 8 MB are refused without uploading', () async {
      build(kycStatus(draft: completeDraft));
      await vm.load();
      await vm.upload('id_front', _file(8 * 1024 * 1024 + 1));
      expect(service.uploads, 0);
      expect(vm.uploads['id_front']?.error,
          'This file is too large. Use a file under 8 MB.');
      expect(vm.uploads['id_front']?.retryable, isFalse);
    });

    test('remove deletes the document; failure shows a tile error', () async {
      build(kycStatus(draft: completeDraft, documents: [docJson('id_front')]));
      await vm.load();
      service.deleteError = KycApiException(0, 'No connection.');
      await vm.remove('doc-id_front');
      expect(vm.documentFor('id_front'), isNotNull);
      expect(vm.documentErrors['id_front'], 'No connection.');
      service.deleteError = null;
      await vm.remove('doc-id_front');
      expect(service.deleted, ['doc-id_front']);
      expect(vm.documentFor('id_front'), isNull);
      expect(vm.documentErrors, isEmpty);
    });
  });

  group('submit', () {
    Future<void> ready() async {
      build(kycStatus(
          draft: completeDraft,
          documents: [docJson('id_front'), docJson('id_back')]));
      await vm.load();
      vm.goToStep(4);
    }

    test('success refreshes the controller and exposes submitted', () async {
      await ready();
      final before = controller.refreshCalls;
      await vm.submit();
      expect(service.submits, 1);
      expect(controller.refreshCalls, before + 1);
      expect(vm.submitted, isTrue);
      expect(vm.submitError, isNull);
    });

    test('flushes a pending edit before submitting', () async {
      await ready();
      vm.setCity('Masvingo');
      await vm.submit();
      expect(service.saved.last.address.city, 'Masvingo');
      expect(service.submits, 1);
    });

    test('client errors jump to the first failing step without calling the server',
        () async {
      await ready();
      vm.setLastName('');
      await vm.submit();
      expect(service.submits, 0);
      expect(vm.step, 0);
      expect(vm.errors['personal.lastName'], 'Enter your last name.');
    });

    test('server field errors map and jump to the step', () async {
      await ready();
      final before = controller.refreshCalls;
      service.submitError = KycValidationException(
          {'address.city': 'Enter your city or town.', 'documents.id_back': 'Upload this document.'},
          'Some details need fixing.');
      await vm.submit();
      expect(vm.submitted, isFalse);
      expect(vm.step, 1);
      expect(vm.errors['address.city'], 'Enter your city or town.');
      expect(vm.errors['documents.id_back'], 'Upload this document.');
      expect(controller.refreshCalls, before);
    });

    test('other errors stay on review with a message', () async {
      await ready();
      service.submitError = KycApiException(503,
          'Verification is temporarily unavailable. Please try again later.');
      await vm.submit();
      expect(vm.step, 4);
      expect(vm.submitting, isFalse);
      expect(vm.submitError,
          'Verification is temporarily unavailable. Please try again later.');
    });
  });

  group('fresh load (C1)', () {
    test('always refreshes and uses the fresh draft over the cached one', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        final fresh = Map<String, dynamic>.from(completeDraft);
        fresh['address'] = {
          'line1': '12 Samora Machel Ave',
          'city': 'Bulawayo',
          'country': 'Zimbabwe',
        };
        controller.next = kycStatus(draft: fresh);
        vm.load();
        async.flushMicrotasks();
        expect(controller.refreshCalls, 1);
        expect(vm.city, 'Bulawayo');
        expect(vm.staleNotice, isNull);
        vm.setFirstName('Rudo');
        async.elapse(const Duration(milliseconds: 800));
        expect(service.saved.single.address.city, 'Bulawayo');
      });
    });

    test('falls back to the cached status with a notice when refresh fails',
        () async {
      build(kycStatus(draft: completeDraft));
      controller.failWith = 'No connection. Check your internet and try again.';
      await vm.load();
      expect(vm.loadError, isNull);
      expect(vm.city, 'Harare');
      expect(vm.staleNotice,
          'Could not load your latest details. Showing what was saved earlier.');
    });
  });

  group('dispose (I1)', () {
    test('final save waits for the save in flight, then refreshes', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        vm.load();
        async.flushMicrotasks();
        final refreshesAfterLoad = controller.refreshCalls;
        service.saveGate = Completer<void>();
        vm.setCity('Old');
        async.elapse(const Duration(milliseconds: 800));
        expect(service.saved, hasLength(1));
        vm.setCity('New');
        vm.dispose();
        async.flushMicrotasks();
        expect(service.saved, hasLength(1),
            reason: 'must not start before the older save finishes');
        service.saveGate!.complete();
        async.flushMicrotasks();
        expect(service.saved.map((d) => d.address.city), ['Old', 'New']);
        expect(controller.refreshCalls, refreshesAfterLoad + 1);
        // tearDown disposes again; make that a no-op.
        vm = KycFormViewModel(service, controller);
      });
    });

    test('saves on dispose whenever dirty, even after a failed save', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        vm.load();
        async.flushMicrotasks();
        service.saveError = KycApiException(0, 'offline');
        vm.setCity('Kwekwe');
        async.elapse(const Duration(milliseconds: 800));
        expect(vm.saveState, KycSaveState.error);
        service.saveError = null;
        vm.dispose();
        async.flushMicrotasks();
        expect(service.saved, hasLength(2));
        expect(service.saved.last.address.city, 'Kwekwe');
        vm = KycFormViewModel(service, controller);
      });
    });
  });

  group('proof of residence (I2)', () {
    test('stays visible and required after the proof document is removed',
        () async {
      build(kycStatus(
          draft: completeDraft,
          documents: [
            docJson('id_front'),
            docJson('id_back'),
            docJson('proof_of_residence'),
          ]));
      await vm.load();
      await vm.remove('doc-proof_of_residence');
      expect(vm.documentKinds, contains('proof_of_residence'));
      vm.goToStep(3);
      expect(vm.next(), isFalse);
      expect(vm.errors['documents.proof_of_residence'], 'Upload this document.');
    });

    test('a server error for proof shows the tile', () async {
      build(kycStatus(
          draft: completeDraft,
          documents: [docJson('id_front'), docJson('id_back')]));
      await vm.load();
      expect(vm.documentKinds, isNot(contains('proof_of_residence')));
      vm.goToStep(4);
      service.submitError = KycValidationException(
          {'documents.proof_of_residence': 'Upload this document.'},
          'Some details need fixing.');
      await vm.submit();
      expect(vm.step, 3);
      expect(vm.documentKinds, contains('proof_of_residence'));
    });
  });

  group('read-only (I3)', () {
    for (final s in ['PENDING_REVIEW', 'APPROVED']) {
      test('$s is read-only and never saves', () async {
        build(kycStatus(draft: completeDraft, status: s));
        await vm.load();
        expect(vm.readOnly, isTrue);
        expect(vm.lockedStatus, s);
        vm.setCity('Harare 2');
        vm.dispose();
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(service.saved, isEmpty);
        vm = KycFormViewModel(service, controller);
      });
    }
  });

  group('save errors (I4)', () {
    test('a 400 on save maps field errors and is not a connection error', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        vm.load();
        async.flushMicrotasks();
        service.saveError = KycValidationException(
            {'personal.firstName': 'Use 60 characters or fewer.'},
            'Some details are invalid.');
        vm.setFirstName('x');
        async.elapse(const Duration(milliseconds: 800));
        expect(vm.saveState, KycSaveState.error);
        expect(vm.errors['personal.firstName'], 'Use 60 characters or fewer.');
        expect(vm.saveError, 'Some details are invalid.');
      });
    });

    test('other server errors show their own message; offline shows none', () {
      fakeAsync((async) {
        build(kycStatus(draft: completeDraft));
        vm.load();
        async.flushMicrotasks();
        service.saveError = KycApiException(429, 'Too many attempts. Please wait a few minutes.');
        vm.setFirstName('x');
        async.elapse(const Duration(milliseconds: 800));
        expect(vm.saveError, 'Too many attempts. Please wait a few minutes.');
        service.saveError = KycApiException(0, 'No connection.');
        vm.setFirstName('y');
        async.elapse(const Duration(milliseconds: 800));
        expect(vm.saveState, KycSaveState.error);
        expect(vm.saveError, isNull);
      });
    });
  });

  group('ID type change', () {
    test('clears the masked number and requires a new one', () async {
      build(kycStatus(draft: completeDraft));
      await vm.load();
      vm.goToStep(2);
      vm.setIdType('passport');
      vm.setIdExpiry(DateTime(2035, 1, 1));
      expect(vm.idNumberMasked, isNull);
      expect(vm.next(), isFalse);
      expect(vm.errors['identification.idNumber'], 'Enter your passport number.');
      vm.setIdType('national_id');
      expect(vm.idNumberMasked, '*********A42',
          reason: 'switching back restores the saved number');
      expect(vm.next(), isTrue);
    });

    test('national ID asks for the ID number', () async {
      build(kycStatus(draft: {
        ...completeDraft,
        'identification': {'idType': 'passport', 'idNumberMasked': '*****456'},
      }));
      await vm.load();
      vm.goToStep(2);
      vm.setIdType('national_id');
      expect(vm.next(), isFalse);
      expect(vm.errors['identification.idNumber'], 'Enter your ID number.');
    });
  });
}
