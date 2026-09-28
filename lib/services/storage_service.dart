import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_service.dart';

/// Keeps all the SharedPreferences key names in one place so we never
/// misspell one across different screens.
class _Keys {
  static const streak = 'streak';
  static const totalSessions = 'total_sessions';
  static const plantStage = 'plant_stage';
  static const plantWilted = 'plant_wilted';
  static const username = 'username';
  static const harvestedPlants = 'harvested_plants';
  static const notesText = 'notes_text';
  static const email = 'email';
  static const isGuest = 'is_guest';
  static const memberSinceYear = 'member_since_year';
  static const plantSpecies = 'plant_species';
  static const harvestLog = 'harvest_log';
  static const avatar = 'avatar_base64';
  static const avatarPixel = 'avatar_pixel';
  static const focusMinutes = 'focus_minutes';

  static const all = [
    streak, totalSessions, plantStage, plantWilted, username,
    harvestedPlants, notesText, email, isGuest, memberSinceYear,
    plantSpecies, harvestLog, avatar, avatarPixel, focusMinutes,
  ];
}

/// The plant id old saves didn't record (before there was more than one
/// kind of plant, every harvest was a Wild Sunflower).
const _legacySpecies = 'wild_sunflower';

/// The one place the app reads and saves its data.
///
/// Two layers work together:
///  * SharedPreferences = a fast on-device copy, so screens can read
///    values instantly (and the app still works offline).
///  * Cloud Firestore = the real database. Once a user is signed in
///    (see [attachUser]), every change is also pushed to their
///    `users/{uid}` document, and their saved data is pulled down on
///    login so it follows them to any device.
///
/// It's a ChangeNotifier so screens like Garden and Profile refresh
/// when the numbers change.
class StorageService extends ChangeNotifier {
  StorageService(this._prefs);

  final SharedPreferences _prefs;
  CloudService? _cloud;
  Timer? _syncTimer;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // ---------------------------------------------------------------------
  // Signing in / out
  // ---------------------------------------------------------------------

  /// Call right after a successful login (or when the app opens with
  /// someone already signed in). Pulls that user's saved data from
  /// Firestore into the local copy — or, for a brand-new account,
  /// starts them fresh and creates their document.
  Future<void> attachUser({
    required String uid,
    String? displayName,
    String? email,
    required bool isGuest,
  }) async {
    _syncTimer?.cancel();
    final cloud = CloudService(uid);
    _cloud = cloud;

    Map<String, dynamic>? data;
    var reachedDatabase = true;
    try {
      data = await cloud.loadUser();
    } catch (error) {
      // Couldn't reach Firestore (offline). Keep whatever is on this
      // device rather than treating them as a new user, otherwise we'd
      // risk overwriting their real data with an empty one.
      reachedDatabase = false;
      debugPrint('Could not load cloud data: $error');
    }

    if (reachedDatabase && data == null) {
      // Brand-new account: start clean and create the document.
      await _clearLocal();
      final name = (displayName ?? '').trim();
      await _prefs.setString(_Keys.username, name.isNotEmpty ? name : (isGuest ? 'Guest Trainee' : 'PlantLover'));
      await _prefs.setInt(_Keys.memberSinceYear, DateTime.now().year);
      await _prefs.setString(_Keys.email, email ?? '');
      await _prefs.setBool(_Keys.isGuest, isGuest);
      await _pushNow(isNew: true);
    } else if (data != null) {
      await _applyCloudData(data);
      await _prefs.setString(_Keys.email, email ?? '');
      await _prefs.setBool(_Keys.isGuest, isGuest);
    }
    notifyListeners();
  }

  /// Call when signing out: saves anything still pending, then wipes the
  /// on-device copy so the next person to log in doesn't see this data.
  Future<void> detachUser() async {
    _syncTimer?.cancel();
    await _pushNow();
    _cloud = null;
    await _clearLocal();
    notifyListeners();
  }

  Future<void> _applyCloudData(Map<String, dynamic> data) async {
    int asInt(Object? v) => v is num ? v.toInt() : 0;

    await _prefs.setInt(_Keys.streak, asInt(data['streak']));
    await _prefs.setInt(_Keys.totalSessions, asInt(data['totalSessions']));
    await _prefs.setInt(_Keys.harvestedPlants, asInt(data['harvestedPlants']));
    await _prefs.setInt(_Keys.plantStage, asInt(data['plantStage']));
    await _prefs.setBool(_Keys.plantWilted, data['plantWilted'] == true);
    await _prefs.setString(_Keys.notesText, data['notes']?.toString() ?? '');
    await _prefs.setString(_Keys.plantSpecies, data['plantSpecies']?.toString() ?? _legacySpecies);
    final log = data['harvestLog'];
    await _prefs.setStringList(_Keys.harvestLog, log is List ? log.map((e) => e.toString()).toList() : const []);
    await _prefs.setString(_Keys.avatar, data['avatar']?.toString() ?? '');
    await _prefs.setBool(_Keys.avatarPixel, data['avatarPixel'] != false);
    final minutes = data['focusMinutes'];
    if (minutes is num && minutes > 0) await _prefs.setInt(_Keys.focusMinutes, minutes.toInt());

    final name = data['username']?.toString() ?? '';
    if (name.isNotEmpty) await _prefs.setString(_Keys.username, name);

    final year = data['memberSinceYear'];
    if (year is int) await _prefs.setInt(_Keys.memberSinceYear, year);
  }

  Future<void> _clearLocal() async {
    for (final key in _Keys.all) {
      await _prefs.remove(key);
    }
  }

  // ---------------------------------------------------------------------
  // Syncing to Firestore
  // ---------------------------------------------------------------------

  Map<String, dynamic> _snapshot() => {
        'username': username,
        'streak': streak,
        'totalSessions': totalSessions,
        'harvestedPlants': harvestedPlants,
        'plantStage': savedPlantStage,
        'plantWilted': savedPlantWilted,
        'plantSpecies': savedPlantSpecies,
        'harvestLog': harvestLog,
        'avatarPixel': avatarPixelated,
        'focusMinutes': focusMinutes,
        // The photo itself is NOT in here on purpose — it's ~30 KB, so it's
        // only uploaded when it changes (see setAvatar), not on every sync.
        'notes': savedNotes,
        'email': email,
        'isGuest': isGuest,
      };

  Future<void> _pushNow({bool isNew = false}) async {
    final cloud = _cloud;
    if (cloud == null) return;
    try {
      await cloud.saveUser(_snapshot(), isNew: isNew).timeout(const Duration(seconds: 5));
    } catch (error) {
      // Firestore keeps the write queued and retries once the phone is
      // back online, so a timeout here isn't lost data.
      debugPrint('Cloud sync did not finish: $error');
    }
  }

  /// Waits a second before pushing, so rapid changes (like typing notes)
  /// become one write instead of hundreds.
  void _scheduleSync() {
    if (_cloud == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 1), () {
      _pushNow();
    });
  }

  // ---------------------------------------------------------------------
  // Streak & session count (shown on the Garden screen)
  // ---------------------------------------------------------------------

  int get streak => _prefs.getInt(_Keys.streak) ?? 0;
  int get totalSessions => _prefs.getInt(_Keys.totalSessions) ?? 0;

  Future<void> recordCompletedSession({int durationSeconds = 0}) async {
    await _prefs.setInt(_Keys.streak, streak + 1);
    await _prefs.setInt(_Keys.totalSessions, totalSessions + 1);
    unawaited(_cloud?.logSession(completed: true, seconds: durationSeconds) ?? Future.value());
    _scheduleSync();
    notifyListeners();
  }

  /// Called on a failed/abandoned session — breaks the streak but the
  /// total session count still counts the attempt.
  Future<void> recordFailedSession({int elapsedSeconds = 0}) async {
    await _prefs.setInt(_Keys.streak, 0);
    await _prefs.setInt(_Keys.totalSessions, totalSessions + 1);
    unawaited(_cloud?.logSession(completed: false, seconds: elapsedSeconds) ?? Future.value());
    _scheduleSync();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Garden (plants that reached fully-grown and were "harvested")
  // ---------------------------------------------------------------------

  int get harvestedPlants => _prefs.getInt(_Keys.harvestedPlants) ?? 0;

  /// Which plant each harvest was, oldest first — e.g.
  /// ['wild_sunflower', 'wild_sunflower', 'desert_cactus'].
  /// Harvests from before this list existed are counted as sunflowers.
  List<String> get harvestLog {
    final log = _prefs.getStringList(_Keys.harvestLog) ?? const <String>[];
    final missing = harvestedPlants - log.length;
    return [for (var i = 0; i < missing; i++) _legacySpecies, ...log];
  }

  /// How many of one kind of plant have been grown.
  int harvestedCountOf(String speciesId) => harvestLog.where((id) => id == speciesId).length;

  Future<void> recordHarvestedPlant({required String speciesId}) async {
    final log = harvestLog; // read before bumping the count (keeps old sunflowers)
    await _prefs.setStringList(_Keys.harvestLog, [...log, speciesId]);
    await _prefs.setInt(_Keys.harvestedPlants, harvestedPlants + 1);
    _scheduleSync();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Plant progress (so it's still there when the app is reopened)
  // ---------------------------------------------------------------------

  int get savedPlantStage => _prefs.getInt(_Keys.plantStage) ?? 0;
  bool get savedPlantWilted => _prefs.getBool(_Keys.plantWilted) ?? false;

  String get savedPlantSpecies => _prefs.getString(_Keys.plantSpecies) ?? _legacySpecies;

  Future<void> savePlantState({required int stageIndex, required bool wilted}) async {
    await _prefs.setInt(_Keys.plantStage, stageIndex);
    await _prefs.setBool(_Keys.plantWilted, wilted);
    _scheduleSync();
  }

  /// Remembers which seed is planted (chosen on the Home screen).
  Future<void> savePlantSpecies(String speciesId) async {
    await _prefs.setString(_Keys.plantSpecies, speciesId);
    _scheduleSync();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Study notes
  // ---------------------------------------------------------------------

  String get savedNotes => _prefs.getString(_Keys.notesText) ?? '';

  Future<void> saveNotes(String text) async {
    await _prefs.setString(_Keys.notesText, text);
    _scheduleSync();
  }

  // ---------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------

  String get username => _prefs.getString(_Keys.username) ?? 'PlantLover';
  String get email => _prefs.getString(_Keys.email) ?? '';
  bool get isGuest => _prefs.getBool(_Keys.isGuest) ?? false;
  int get memberSinceYear => _prefs.getInt(_Keys.memberSinceYear) ?? DateTime.now().year;

  // ---------------------------------------------------------------------
  // Focus time (the FOCUS TIME setter on Home)
  // ---------------------------------------------------------------------

  /// How long a study session lasts, in minutes. 25 = classic Pomodoro.
  int get focusMinutes => _prefs.getInt(_Keys.focusMinutes) ?? 25;

  Future<void> setFocusMinutes(int minutes) async {
    await _prefs.setInt(_Keys.focusMinutes, minutes);
    _scheduleSync();
    notifyListeners();
  }

  Future<void> setUsername(String name) async {
    await _prefs.setString(_Keys.username, name);
    _scheduleSync();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Profile photo (small JPEG, saved as text so it fits in SharedPreferences
  // and in the Firestore user document — no Firebase Storage needed)
  // ---------------------------------------------------------------------

  String? _avatarCacheKey;
  Uint8List? _avatarCache;

  /// The profile photo, or null if none has been chosen.
  Uint8List? get avatarBytes {
    final encoded = _prefs.getString(_Keys.avatar) ?? '';
    if (encoded.isEmpty) return null;
    if (encoded != _avatarCacheKey) {
      // Decoding every rebuild would be wasteful, so remember the result.
      _avatarCacheKey = encoded;
      try {
        _avatarCache = base64Decode(encoded);
      } catch (_) {
        _avatarCache = null;
      }
    }
    return _avatarCache;
  }

  /// true = show the photo as chunky pixels to match the game.
  bool get avatarPixelated => _prefs.getBool(_Keys.avatarPixel) ?? true;

  /// Saves a new photo (or removes it when [bytes] is null) and uploads it
  /// right away — separately from the regular sync, since it's the one
  /// big field.
  Future<void> setAvatar(Uint8List? bytes) async {
    final encoded = bytes == null ? '' : base64Encode(bytes);
    await _prefs.setString(_Keys.avatar, encoded);
    notifyListeners();
    final cloud = _cloud;
    if (cloud == null) return;
    try {
      await cloud.saveUser({'avatar': encoded}).timeout(const Duration(seconds: 10));
    } catch (error) {
      // Firestore keeps the write queued and retries when back online.
      debugPrint('Avatar upload did not finish: $error');
    }
  }

  Future<void> setAvatarPixelated(bool value) async {
    await _prefs.setBool(_Keys.avatarPixel, value);
    _scheduleSync();
    notifyListeners();
  }
}
