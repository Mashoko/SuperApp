import '../../../../core/utils/result.dart';
import '../../../recents/data/models/recent_call.dart';

abstract class DialpadRepository {
  Future<Result<String>> getSavedDestination();
  Future<Result<void>> saveDestination(String destination);
  Future<Result<List<RecentCall>>> getRecents();
  Future<Result<void>> addRecent(RecentCall call);
}

