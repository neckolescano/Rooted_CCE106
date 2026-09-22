import 'package:shared_preferences/shared_preferences.dart';

/// Keeps all the SharedPreferences key names in one place so we never
/// misspell one across different screens.
class _Keys {
  static const streak = 'streak';
  static const totalSessions = 'total_sessions';
  static const plantStage = 'plant_stage';
  static const plantWilted = 'plant_wilted';
  static const username = 'username';
  static const harvestedPlants = 'harvested_plants';
}

/// A thin wrapper around SharedPreferences. Every screen that needs to
/// read or save data goes through this instead of touching
/// SharedPreferences directly — keeps things tidy and easy to swap out
/// for a real database later if the app grows.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Streak & session count (shown on the Garden screen) ---

  int get streak => _prefs.getInt(_Keys.streak) ?? 0;
  int get totalSessions => _prefs.getInt(_Keys.totalSessions) ?? 0;

  Future<void> recordCompletedSession() async {
    await _prefs.setInt(_Keys.streak, streak + 1);
    await _prefs.setInt(_Keys.totalSessions, totalSessions + 1);
  }

  /// Called on a failed/abandoned session — breaks the streak but the
  /// total session count still counts the attempt.
  Future<void> recordFailedSession() async {
    await _prefs.setInt(_Keys.streak, 0);
    await _prefs.setInt(_Keys.totalSessions, totalSessions + 1);
  }

  // --- Garden (plants that reached fully-grown and were "harvested") ---

  int get harvestedPlants => _prefs.getInt(_Keys.harvestedPlants) ?? 0;

  /// Called once, the moment a plant reaches its final growth stage —
  /// this is what the Garden screen's real count is based on.
  Future<void> recordHarvestedPlant() async {
    await _prefs.setInt(_Keys.harvestedPlants, harvestedPlants + 1);
  }

  // --- Plant progress (so it's still there when the app is reopened) ---

  int get savedPlantStage => _prefs.getInt(_Keys.plantStage) ?? 0;
  bool get savedPlantWilted => _prefs.getBool(_Keys.plantWilted) ?? false;

  Future<void> savePlantState({required int stageIndex, required bool wilted}) async {
    await _prefs.setInt(_Keys.plantStage, stageIndex);
    await _prefs.setBool(_Keys.plantWilted, wilted);
  }

  // --- Profile ---

  String get username => _prefs.getString(_Keys.username) ?? 'PlantLover42';

  Future<void> setUsername(String name) async {
    await _prefs.setString(_Keys.username, name);
  }
}
