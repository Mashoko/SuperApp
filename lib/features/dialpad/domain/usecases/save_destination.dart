import '../repositories/dialpad_repository.dart';
import '../../../../core/utils/result.dart';

class SaveDestination {
  final DialpadRepository repository;

  SaveDestination(this.repository);

  Future<Result<void>> call(String destination) {
    return repository.saveDestination(destination);
  }
}

