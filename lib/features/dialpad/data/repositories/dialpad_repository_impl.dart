import 'dart:convert';
import '../../domain/repositories/dialpad_repository.dart';
import '../../../../core/utils/result.dart';
import '../datasources/dialpad_local_data_source.dart';
import '../../../recents/data/models/recent_call.dart';

class DialpadRepositoryImpl implements DialpadRepository {
  final DialpadLocalDataSource localDataSource;

  DialpadRepositoryImpl(this.localDataSource);

  @override
  Future<Result<String>> getSavedDestination() async {
    try {
      final destination = await localDataSource.getSavedDestination();
      return Success(destination);
    } catch (e) {
      return Failure('Failed to get saved destination: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> saveDestination(String destination) async {
    try {
      await localDataSource.saveDestination(destination);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save destination: ${e.toString()}');
    }
  }

  @override
  Future<Result<List<RecentCall>>> getRecents() async {
    try {
      final jsonList = await localDataSource.getRecents();
      final recents = jsonList
          .map((jsonStr) => RecentCall.fromJson(jsonDecode(jsonStr)))
          .toList();
      return Success(recents);
    } catch (e) {
      return Failure('Failed to get recents: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> addRecent(RecentCall call) async {
    try {
      final jsonList = await localDataSource.getRecents();
      final newJsonList = List<String>.from(jsonList);
      newJsonList.insert(0, jsonEncode(call.toJson())); // Add to top
      // Limit to 50
      if (newJsonList.length > 50) {
        newJsonList.removeLast();
      }
      await localDataSource.saveRecents(newJsonList);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add recent: ${e.toString()}');
    }
  }
}

