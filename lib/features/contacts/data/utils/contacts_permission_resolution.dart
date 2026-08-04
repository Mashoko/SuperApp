import 'package:permission_handler/permission_handler.dart';

enum ContactsPermissionState { unknown, granted, denied, permanentlyDenied }

/// Maps a raw [PermissionStatus] to the tri-state the Contacts screen
/// renders around. Pure and side-effect-free so it's testable without a
/// live platform-channel call.
ContactsPermissionState resolvePermissionState(PermissionStatus status) {
  if (status.isGranted) return ContactsPermissionState.granted;
  if (status.isPermanentlyDenied) return ContactsPermissionState.permanentlyDenied;
  return ContactsPermissionState.denied;
}
