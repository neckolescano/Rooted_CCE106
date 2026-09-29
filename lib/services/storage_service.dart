import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/garden_progress.dart';
import '../models/session_log.dart';
import '../models/study_material.dart';
import '../models/study_options.dart';
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
  static const studyOptions = 'study_options';
  static const cardDesign = 'card_design';
  static const gardenScene = 'garden_scene';
  static const secrets = 'secrets';
  static const studyMaterial = 'study_material';
  static const completedSessions = 'completed_sessions';
  static const remindersOn = 'reminders_on';
  static const reminderMinutes = 'reminder_minutes';
  static const lastStudyDay = 'last_study_day';

  /// Which account the data on this phone belongs to. Only set once that
  /// account's data was really loaded from (or created in) the cloud.
  static const owner = 'local_owner_uid';

  static const all = [
    streak, totalSessions, plantStage, plantWilted, username,
    harvestedPlants, notesText, email, isGuest, memberSinceYear,
    plantSpecies, harvestLog, avatar, avatarPixel, focusMinutes, studyOptions, cardDesign,
    studyMaterial, completedSessions, remindersOn, reminderMinutes, lastStudyDay, gardenScene, secrets, owner,
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
  /// [cloudFor] makes the Firestore connection for a signed-in user —
  /// tests pass a stand-in so the sync rules can be checked without Firebase.
  StorageService(this._prefs, {CloudService Function(String uid)? cloudFor}) : _cloudFor = cloudFor ?? CloudService.new;

  final CloudService Function(String uid) _cloudFor;

  final SharedPreferences _prefs;
  CloudService? _cloud;
  Timer? _syncTimer;

  /// true once the local copy is known to be this user's real data, so
  /// it's safe to push it to the cloud. While false, NOTHING is uploaded
  /// — otherwise an empty/default local copy (new phone, or right after a
  /// sign-out) would overwrite the user's real progress in Firestore.
  bool _cloudReady = false;

  /// The loaded account had no completedSessions yet; write the seeded
  /// value with the next upload.
  bool _seedCompletedInCloud = false;
  Timer? _retryTimer;
  int _retryCount = 0;

  /// Called when the user's cloud data arrives late (the first load timed
  /// out and a background retry succeeded), so the plant and notes models
  /// can reload from it. Set once at start-up (see main.dart).
  VoidCallback? onCloudDataRestored;

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
    _retryTimer?.cancel();
    _retryCount = 0;
    _cloudReady = false;
    final cloud = _cloudFor(uid);
    _cloud = cloud;

    Map<String, dynamic>? data;
    var reachedDatabase = true;
    try {
      data = await cloud.loadUser();
    } catch (error) {
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
      await _markLocalAsOwnedBy(uid);
      await _pushNow(isNew: true);
    } else if (data != null) {
      await _applyCloudData(data);
      await _prefs.setString(_Keys.email, email ?? '');
      await _prefs.setBool(_Keys.isGuest, isGuest);
      await _markLocalAsOwnedBy(uid);
    } else if (_prefs.getString(_Keys.owner) == uid ||
        // Saves from before the owner mark existed: signing out always
        // wiped this phone, so leftover data can only be this user's.
        (_prefs.getString(_Keys.owner) == null && _prefs.containsKey(_Keys.username))) {
      // Couldn't reach Firestore (offline / slow), but this phone already
      // holds THIS user's data from before — keep using it and keep
      // syncing (Firestore queues the writes until it's back online).
      _cloudReady = true;
    } else {
      // Couldn't reach Firestore AND the local copy isn't this user's
      // (new phone, or just signed out). Don't upload anything — that
      // would overwrite their real progress with empty defaults. Keep
      // trying to load in the background instead.
      debugPrint('[Storage] cloud data not loaded yet — uploads paused, retrying in the background');
      await _clearLocal();
      await _prefs.setString(_Keys.email, email ?? '');
      await _prefs.setBool(_Keys.isGuest, isGuest);
      _scheduleCloudRetry(uid, displayName: displayName, email: email, isGuest: isGuest);
    }
    notifyListeners();
  }

  Future<void> _markLocalAsOwnedBy(String uid) async {
    await _prefs.setString(_Keys.owner, uid);
    _cloudReady = true;
    if (_seedCompletedInCloud) _scheduleSync(); // upload the seeded counter
  }

  /// Retries loading the user's cloud data with growing gaps (3 s, 6 s,
  /// 12 s … up to a minute) until it works or the user signs out.
  void _scheduleCloudRetry(String uid, {String? displayName, String? email, required bool isGuest}) {
    final seconds = min(60, 3 * (1 << min(_retryCount, 5)));
    _retryCount++;
    _retryTimer = Timer(Duration(seconds: seconds), () async {
      final cloud = _cloud;
      if (cloud == null || cloud.uid != uid) return; // signed out meanwhile
      try {
        final data = await cloud.loadUser();
        if (_cloud != cloud) return;
        if (data != null) {
          await _applyCloudData(data);
        } else {
          // Genuinely new account (its document was never created): start it.
          final name = (displayName ?? '').trim();
          await _prefs.setString(_Keys.username, name.isNotEmpty ? name : (isGuest ? 'Guest Trainee' : 'PlantLover'));
          await _prefs.setInt(_Keys.memberSinceYear, DateTime.now().year);
        }
        await _prefs.setString(_Keys.email, email ?? '');
        await _prefs.setBool(_Keys.isGuest, isGuest);
        await _markLocalAsOwnedBy(uid);
        if (data == null) await _pushNow(isNew: true);
        debugPrint('[Storage] cloud data loaded on retry $_retryCount');
        onCloudDataRestored?.call();
        notifyListeners();
      } catch (error) {
        debugPrint('[Storage] retry $_retryCount failed: $error');
        if (_cloud == cloud) _scheduleCloudRetry(uid, displayName: displayName, email: email, isGuest: isGuest);
      }
    });
  }

  /// Call when signing out: saves anything still pending (only if it's
  /// safe to), then wipes the on-device copy so the next person to log in
  /// doesn't see this data. [push] = false when the user is already signed
  /// out of Firebase (writes would be rejected).
  Future<void> detachUser({bool push = true}) async {
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    if (push) await _pushNow();
    _cloud = null;
    _cloudReady = false;
    await _clearLocal();
    notifyListeners();
  }

  /// Pushes any pending changes right away (e.g. before signing out).
  Future<void> syncNow() async {
    _syncTimer?.cancel();
    await _pushNow();
  }

  /// The signed-in user's recent study sessions (for the Study Log).
  /// Throws if they can't be loaded; empty when nobody is signed in.
  Future<List<SessionLogEntry>> loadSessionHistory() async {
    final cloud = _cloud;
    if (cloud == null) return const [];
    return cloud.recentSessions();
  }

  Future<void> _applyCloudData(Map<String, dynamic> data) async {
    int asInt(Object? v) => v is num ? v.toInt() : 0;

    await _prefs.setInt(_Keys.streak, asInt(data['streak']));
    await _prefs.setInt(_Keys.totalSessions, asInt(data['totalSessions']));
    await _prefs.setInt(_Keys.harvestedPlants, asInt(data['harvestedPlants']));
    final completed = data['completedSessions'];
    if (completed is num) {
      await _prefs.setInt(_Keys.completedSessions, completed.toInt());
    } else {
      // Account from before the real counter: seed it once from the old
      // estimate (written to the cloud when the load finishes).
      await _prefs.setInt(
        _Keys.completedSessions,
        GardenProgress.estimateCompleted(
          harvestedPlants: asInt(data['harvestedPlants']),
          plantStageIndex: asInt(data['plantStage']),
        ),
      );
      _seedCompletedInCloud = true;
    }
    await _prefs.setInt(_Keys.plantStage, asInt(data['plantStage']));
    await _prefs.setBool(_Keys.plantWilted, data['plantWilted'] == true);
    await _prefs.setString(_Keys.notesText, data['notes']?.toString() ?? '');
    await _prefs.setString(_Keys.plantSpecies, data['plantSpecies']?.toString() ?? _legacySpecies);
    final log = data['harvestLog'];
    await _prefs.setStringList(_Keys.harvestLog, log is List ? log.map((e) => e.toString()).toList() : const []);
    await _prefs.setString(_Keys.avatar, data['avatar']?.toString() ?? '');
    await _prefs.setBool(_Keys.avatarPixel, data['avatarPixel'] != false);
    final material = data['studyMaterial'];
    if (material is Map) {
      await _prefs.setString(_Keys.studyMaterial, jsonEncode(material));
    } else {
      await _prefs.remove(_Keys.studyMaterial);
    }
    final scene = data['gardenScene'];
    if (scene is String && scene.isNotEmpty) await _prefs.setString(_Keys.gardenScene, scene);
    final found = data['secrets'];
    if (found is List) await _prefs.setStringList(_Keys.secrets, [for (final f in found) f.toString()]);
    final design = data['cardDesign'];
    if (design is String && design.isNotEmpty) await _prefs.setString(_Keys.cardDesign, design);
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

  /// Everything saved in the user document. The COUNTERS (sessions,
  /// completed sessions, plants grown) are only included when the
  /// document is first created — after that they're only ever changed
  /// with +1 increments (see CloudService.increment), so two phones
  /// can't overwrite each other's counts.
  Map<String, dynamic> _snapshot({bool withCounters = false}) => {
        'username': username,
        'streak': streak,
        if (withCounters) 'totalSessions': totalSessions,
        if (withCounters) 'completedSessions': completedSessions,
        if (withCounters) 'harvestedPlants': harvestedPlants,
        'plantStage': savedPlantStage,
        'plantWilted': savedPlantWilted,
        'plantSpecies': savedPlantSpecies,
        'harvestLog': harvestLog,
        'avatarPixel': avatarPixelated,
        'focusMinutes': focusMinutes,
        'cardDesign': cardDesign,
        'gardenScene': gardenScene,
        'secrets': secrets.toList(),
        // The photo itself is NOT in here on purpose — it's ~30 KB, so it's
        // only uploaded when it changes (see setAvatar), not on every sync.
        'notes': savedNotes,
        'email': email,
        'isGuest': isGuest,
      };

  Future<void> _pushNow({bool isNew = false}) async {
    final cloud = _cloud;
    // Never upload a local copy that isn't known to be this user's data.
    if (cloud == null || !_cloudReady) return;
    try {
      final data = _snapshot(withCounters: isNew);
      if (_seedCompletedInCloud) data['completedSessions'] = completedSessions;
      await cloud.saveUser(data, isNew: isNew).timeout(const Duration(seconds: 5));
      _seedCompletedInCloud = false;
    } catch (error) {
      // Firestore keeps the write queued and retries once the phone is
      // back online, so a timeout here isn't lost data.
      debugPrint('Cloud sync did not finish: $error');
    }
  }

  /// Waits a second before pushing, so rapid changes (like typing notes)
  /// become one write instead of hundreds.
  void _scheduleSync() {
    if (_cloud == null || !_cloudReady) return; // see _cloudReady
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

  /// Sessions actually FINISHED (not given up) — drives XP, level, plant
  /// unlocks, badges and card quests. Older saves without the counter
  /// fall back to the old estimate until the first new session.
  int get completedSessions =>
      _prefs.getInt(_Keys.completedSessions) ??
      GardenProgress.estimateCompleted(harvestedPlants: harvestedPlants, plantStageIndex: savedPlantStage);

  /// Adds to cloud counters (only once the cloud data is really loaded).
  void _incrementInCloud(Map<String, int> by) {
    final cloud = _cloud;
    if (cloud == null || !_cloudReady) return; // see _cloudReady
    unawaited(cloud.increment(by));
  }

  Future<void> recordCompletedSession({int durationSeconds = 0}) async {
    await _prefs.setString(_Keys.lastStudyDay, _today());
    await _prefs.setInt(_Keys.completedSessions, completedSessions + 1);
    await _prefs.setInt(_Keys.streak, streak + 1);
    await _prefs.setInt(_Keys.totalSessions, totalSessions + 1);
    _incrementInCloud({'totalSessions': 1, 'completedSessions': 1});
    unawaited(_cloud?.logSession(completed: true, seconds: durationSeconds) ?? Future.value());
    _scheduleSync();
    notifyListeners();
  }

  /// Called on a failed/abandoned session — breaks the streak but the
  /// total session count still counts the attempt.
  Future<void> recordFailedSession({int elapsedSeconds = 0}) async {
    await _prefs.setInt(_Keys.streak, 0);
    await _prefs.setInt(_Keys.totalSessions, totalSessions + 1);
    _incrementInCloud({'totalSessions': 1});
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
    _incrementInCloud({'harvestedPlants': 1});
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

  // ---------------------------------------------------------------------
  // Study reminders (Profile → Push Reminders) — this phone only, since
  // notifications belong to the device. Scheduling: ReminderService.
  // ---------------------------------------------------------------------

  bool get remindersOn => _prefs.getBool(_Keys.remindersOn) ?? false;

  /// Reminder time as minutes after midnight (default 7:00 PM).
  int get reminderMinutes => _prefs.getInt(_Keys.reminderMinutes) ?? 19 * 60;

  /// true if a session was finished today (then today's reminder is skipped).
  bool get studiedToday => _prefs.getString(_Keys.lastStudyDay) == _today();

  Future<void> setReminders({bool? on, int? minutes}) async {
    if (on != null) await _prefs.setBool(_Keys.remindersOn, on);
    if (minutes != null) await _prefs.setInt(_Keys.reminderMinutes, minutes);
    notifyListeners();
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> setFocusMinutes(int minutes) async {
    await _prefs.setInt(_Keys.focusMinutes, minutes);
    _scheduleSync();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Study options (the "Grow your study patch" scroll) — this phone only
  // ---------------------------------------------------------------------

  StudyOptions get studyOptions {
    final raw = _prefs.getString(_Keys.studyOptions);
    if (raw == null) return const StudyOptions();
    try {
      return StudyOptions.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const StudyOptions();
    }
  }

  Future<void> setStudyOptions(StudyOptions options) async {
    await _prefs.setString(_Keys.studyOptions, jsonEncode(options.toJson()));
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Player Card design (unlocked by quests — see models/card_designs.dart)
  // ---------------------------------------------------------------------

  String get cardDesign => _prefs.getString(_Keys.cardDesign) ?? 'meadow';

  /// The equipped Garden Scene (models/garden_scenes.dart): the world
  /// behind the Timer, in the Garden Archive and through the Home window.
  String get gardenScene => _prefs.getString(_Keys.gardenScene) ?? 'meadow';

  Future<void> setGardenScene(String id) async {
    await _prefs.setString(_Keys.gardenScene, id);
    _scheduleSync();
    notifyListeners();
  }

  /// Hidden achievements found so far (see models/secrets.dart).
  Set<String> get secrets => (_prefs.getStringList(_Keys.secrets) ?? const []).toSet();

  /// Records a secret. Returns true only the first time it is found, so the
  /// caller can celebrate it once.
  Future<bool> unlockSecret(String id) async {
    final found = secrets;
    if (found.contains(id)) return false;
    await _prefs.setStringList(_Keys.secrets, [...found, id]);
    _scheduleSync();
    notifyListeners();
    return true;
  }

  Future<void> setCardDesign(String id) async {
    await _prefs.setString(_Keys.cardDesign, id);
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
    if (cloud == null || !_cloudReady) return; // see _cloudReady
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

  // ---------------------------------------------------------------------
  // Study material (the last questions + flashcards generated from the
  // notes) — kept so it's not lost when the screen closes, and synced so
  // it follows the student to other phones.
  // ---------------------------------------------------------------------

  StudyMaterial? get savedStudyMaterial {
    final raw = _prefs.getString(_Keys.studyMaterial);
    if (raw == null) return null;
    try {
      final material = StudyMaterial.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      return material.questions.isEmpty && material.flashcards.isEmpty ? null : material;
    } catch (_) {
      return null; // unreadable save → as if there were none
    }
  }

  /// Saves on the phone right away and uploads it on its own (like the
  /// photo), instead of with every regular sync.
  Future<void> saveStudyMaterial(StudyMaterial material) async {
    final json = material.toJson();
    await _prefs.setString(_Keys.studyMaterial, jsonEncode(json));
    final cloud = _cloud;
    if (cloud == null || !_cloudReady) return; // see _cloudReady
    try {
      await cloud.saveUser({'studyMaterial': json}).timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Study material upload did not finish: $error');
    }
  }
}
