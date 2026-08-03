import '../../features/recents/data/models/call_log_status.dart';

/// Maps the outcome of a terminated call to a [CallLogStatus]. Pure and
/// side-effect-free — takes only primitives extracted from the real
/// `sip_ua` `Call`/`CallState` objects, so it's testable without faking
/// those types.
CallLogStatus resolveCallLogStatus({
  required bool isIncoming,
  required bool didConnect,
  required String causeCode,
}) {
  if (didConnect) return CallLogStatus.completed;
  if (isIncoming) {
    // 487 = caller cancelled (Request Terminated), 408 = timeout — remote
    // party gave up before we answered.
    final callerCancelled = causeCode == '487' || causeCode == '408';
    return callerCancelled ? CallLogStatus.missed : CallLogStatus.declined;
  }
  // Outgoing, never connected: the far end didn't pick up / rejected.
  return CallLogStatus.declined;
}
