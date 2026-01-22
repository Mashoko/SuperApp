import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/constants.dart';

abstract class DialpadLocalDataSource {
  Future<String> getSavedDestination();
  Future<void> saveDestination(String destination);
  Future<List<String>> getRecents();
  Future<void> saveRecents(List<String> recents);
}

class DialpadLocalDataSourceImpl implements DialpadLocalDataSource {
  final SharedPreferences sharedPreferences;

  DialpadLocalDataSourceImpl(this.sharedPreferences);

  @override
  Future<String> getSavedDestination() async {
    return sharedPreferences.getString(AppConstants.keyDestination) ??
        AppConstants.defaultDestination;
  }

  @override
  Future<void> saveDestination(String destination) async {
    await sharedPreferences.setString(AppConstants.keyDestination, destination);
  }

  @override
  Future<List<String>> getRecents() async {
    return sharedPreferences.getStringList('recents_list') ?? [];
  }

  @override
  Future<void> saveRecents(List<String> recents) async {
    await sharedPreferences.setStringList('recents_list', recents);
  }
}

