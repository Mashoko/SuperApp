import 'package:sip_ua/sip_ua.dart';
import '../repositories/call_repository.dart';
import '../../../../core/utils/result.dart';

class AcceptCall {
  final CallRepository repository;

  AcceptCall(this.repository);

  Future<Result<void>> call(Call call, {required bool hasVideo}) {
    return repository.acceptCall(call, hasVideo: hasVideo);
  }
}

