import 'package:flutter/foundation.dart';

/// App-wide "a call is in progress" flag. True from CALL_INITIATION (incoming
/// or outgoing) until every call has ended or failed and the call screen has
/// closed, so the call screen's end state stays visible and usable.
///
/// Read by the KYC gate, which steps aside while a call is active.
class CallActivity extends ValueNotifier<bool> {
  CallActivity() : super(false);

  final Set<String> _calls = {};
  int _openViews = 0;

  void callStarted(String id) {
    _calls.add(id);
    _update();
  }

  void callFinished(String id) {
    _calls.remove(id);
    _update();
  }

  void viewOpened() {
    _openViews++;
    _update();
  }

  /// Defensive: once the last call screen closes, calls that never reported
  /// an end are forgotten so the flag cannot stay stuck on.
  void viewClosed() {
    if (_openViews > 0) _openViews--;
    if (_openViews == 0) _calls.clear();
    _update();
  }

  void _update() => value = _calls.isNotEmpty || _openViews > 0;
}
