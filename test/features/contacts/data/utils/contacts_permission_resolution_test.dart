import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mvvm_sip_demo/features/contacts/data/utils/contacts_permission_resolution.dart';

void main() {
  group('resolvePermissionState', () {
    test('granted maps to granted', () {
      expect(resolvePermissionState(PermissionStatus.granted),
          ContactsPermissionState.granted);
    });

    test('permanentlyDenied maps to permanentlyDenied', () {
      expect(resolvePermissionState(PermissionStatus.permanentlyDenied),
          ContactsPermissionState.permanentlyDenied);
    });

    test('denied maps to denied', () {
      expect(resolvePermissionState(PermissionStatus.denied),
          ContactsPermissionState.denied);
    });

    test('an unexpected status (e.g. restricted) falls back to denied', () {
      expect(resolvePermissionState(PermissionStatus.restricted),
          ContactsPermissionState.denied);
    });
  });
}
