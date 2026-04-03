import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const String _currentLevelKey = 'current_level';
  static const String _imageTutorialSeenKey = 'image_tutorial_seen';
  static const String _scrambleTutorialSeenKey = 'scramble_tutorial_seen';

  Future<int> getCurrentLevel() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentLevelKey) ?? 1;
  }

  Future<void> saveCurrentLevel(int level) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentLevelKey, level);
  }

  Future<void> resetProgress() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentLevelKey);
  }

  Future<bool> hasSeenImageTutorial() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_imageTutorialSeenKey) ?? false;
  }

  Future<void> markImageTutorialSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_imageTutorialSeenKey, true);
  }

  Future<bool> hasSeenScrambleTutorial() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scrambleTutorialSeenKey) ?? false;
  }

  Future<void> markScrambleTutorialSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scrambleTutorialSeenKey, true);
  }
}
