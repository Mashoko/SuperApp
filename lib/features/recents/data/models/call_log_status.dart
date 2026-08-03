/// Final outcome of a logged call.
///
/// - [completed]: the call connected and ended normally, for either
///   direction.
/// - [missed]: an incoming call the remote party cancelled or that timed
///   out before we answered.
/// - [declined]: an incoming call we explicitly rejected, or an outgoing
///   call the far end didn't answer/rejected (including one we hung up
///   ourselves while it was still ringing — deliberately not split into a
///   separate "cancelled" status).
/// - [failed]: the call never reached a normal SIP termination at all
///   (network error, invalid destination, etc.), for either direction.
enum CallLogStatus { completed, missed, declined, failed }
