import 'package:flutter/foundation.dart';

/// App-wide "a call is in progress" flag. True from CALL_INITIATION (incoming
/// or outgoing) until every call has ended or failed and the call screen has
/// closed, so the call screen's end state stays visible and usable.
///
/// Live calls are tracked only from CALL_INITIATION, ENDED and FAILED:
/// closing a call screen never clears a live call, so the KYC gate cannot
/// cover a call that is still ringing or connected.
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

  void viewClosed() {
    if (_openViews > 0) _openViews--;
    _update();
  }

  void _update() => value = _calls.isNotEmpty || _openViews > 0;
}
