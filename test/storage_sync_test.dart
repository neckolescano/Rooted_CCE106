// Checks the cloud-sync safety rules in StorageService (audit Bugs 1, 12,
// 13): a slow or failed first load must NEVER upload empty defaults over the
// user's real data, counters go up with +1 increments, and older accounts
// get their completed-session counter seeded once.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/services/cloud_service.dart';
import 'package:rooted/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for Firestore: remembers what would have been uploaded.
class FakeCloud extends CloudService {
  FakeCloud(super.uid, {this.doc, this.failLoads = 0});

  Map<String, dynamic>? doc; // the user's document "in the cloud"
  int failLoads; // how many loads fail first (offline / timeout)
  final saves = <Map<String, dynamic>>[];
  final newDocs = <Map<String, dynamic>>[];
  final increments = <Map<String, int>>[];

  @override
  Future<Map<String, dynamic>?> loadUser() async {
    if (failLoads > 0) {
      failLoads--;
      throw Exception('offline');
    }
    return doc == null ? null : Map.of(doc!);
  }

  @override
  Future<void> saveUser(Map<String, dynamic> data, {bool isNew = false}) async {
    (isNew ? newDocs : saves).add(data);
  }

  @override
  Future<void> increment(Map<String, int> by) async => increments.add(by);

  @override
  Future<void> logSession({required bool completed, required int seconds}) async {}
}

/// The user's real progress, already in Firestore.
Map<String, dynamic> realDoc() => {
      'username': 'Necko',
      'streak': 4,
      'totalSessions': 30,
      'completedSessions': 26,
      'harvestedPlants': 6,
      'plantStage': 2,
      'plantSpecies': 'desert_cactus',
      'notes': 'Photosynthesis makes glucose.',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Runs [body] with a StorageService on fresh phone storage [local],
  /// talking to [cloud], with fake (skippable) time.
  void withStorage(
    Map<String, Object> local,
    FakeCloud cloud,
    void Function(StorageService storage, FakeAsync time) body,
  ) {
    fakeAsync((time) {
      SharedPreferences.setMockInitialValues(local);
      late StorageService storage;
      SharedPreferences.getInstance().then((prefs) => storage = StorageService(prefs, cloudFor: (_) => cloud));
      time.flushMicrotasks();
      body(storage, time);
    });
  }

  void attach(StorageService storage, FakeAsync time) {
    storage.attachUser(uid: 'u1', displayName: 'Necko', email: 'n@example.com', isGuest: false);
    time.flushMicrotasks();
  }

  test('new phone + cloud unreachable: nothing is uploaded until the real data loads', () {
    final cloud = FakeCloud('u1', doc: realDoc(), failLoads: 1);
    withStorage({}, cloud, (storage, time) {
      var restored = false;
      storage.onCloudDataRestored = () => restored = true;
      attach(storage, time);

      // Playing around while the data hasn't loaded must not touch the cloud.
      storage.recordCompletedSession(durationSeconds: 60);
      storage.setFocusMinutes(10);
      time.elapse(const Duration(seconds: 2));
      expect(cloud.saves, isEmpty, reason: 'would overwrite the real progress with defaults');
      expect(cloud.newDocs, isEmpty);
      expect(cloud.increments, isEmpty);

      // The background retry (after 3 s) loads the real data.
      time.elapse(const Duration(seconds: 3));
      expect(restored, isTrue);
      expect(storage.username, 'Necko');
      expect(storage.completedSessions, 26);
      expect(storage.savedPlantSpecies, 'desert_cactus');

      // From now on changes are uploaded — with the REAL name, not a default.
      storage.setFocusMinutes(30);
      time.elapse(const Duration(seconds: 2));
      expect(cloud.saves.last['username'], 'Necko');
      expect(cloud.saves.last['focusMinutes'], 30);
    });
  });

  test("offline, but the phone already holds this user's data: keeps saving", () {
    final cloud = FakeCloud('u1', doc: realDoc(), failLoads: 99);
    withStorage({'username': 'Necko', 'local_owner_uid': 'u1', 'completed_sessions': 26}, cloud, (storage, time) {
      attach(storage, time);
      storage.setFocusMinutes(45);
      time.elapse(const Duration(seconds: 2));
      expect(cloud.saves, hasLength(1), reason: 'Firestore queues it until back online');
      expect(cloud.saves.single['username'], 'Necko');
    });
  });

  test("another account's leftovers are wiped and never uploaded", () {
    final cloud = FakeCloud('u1', doc: realDoc(), failLoads: 99);
    withStorage({'username': 'SomeoneElse', 'local_owner_uid': 'u2'}, cloud, (storage, time) {
      attach(storage, time);
      expect(storage.username, isNot('SomeoneElse'));
      storage.setFocusMinutes(45);
      time.elapse(const Duration(seconds: 20));
      expect(cloud.saves, isEmpty);
    });
  });

  test('a brand-new account creates its document, counters included', () {
    final cloud = FakeCloud('u1');
    withStorage({}, cloud, (storage, time) {
      attach(storage, time);
      expect(cloud.newDocs, hasLength(1));
      expect(cloud.newDocs.single['username'], 'Necko');
      expect(cloud.newDocs.single['totalSessions'], 0);
      expect(cloud.newDocs.single['completedSessions'], 0);
    });
  });

  test('counters go up with +1 increments and are never overwritten by a sync', () {
    final cloud = FakeCloud('u1', doc: realDoc());
    withStorage({}, cloud, (storage, time) {
      attach(storage, time);
      // One after another, like the app does (each save finishes first).
      storage.recordCompletedSession(durationSeconds: 1500);
      time.flushMicrotasks();
      storage.recordFailedSession(elapsedSeconds: 60);
      time.flushMicrotasks();
      storage.recordHarvestedPlant(speciesId: 'forest_fern');
      time.elapse(const Duration(seconds: 2));

      expect(cloud.increments, [
        {'totalSessions': 1, 'completedSessions': 1},
        {'totalSessions': 1},
        {'harvestedPlants': 1},
      ]);
      expect(cloud.saves.last.containsKey('totalSessions'), isFalse);
      expect(cloud.saves.last.containsKey('harvestedPlants'), isFalse);
      expect(storage.completedSessions, 27);
      expect(storage.totalSessions, 32);
    });
  });

  test('older accounts get their completed-session counter seeded once', () {
    final doc = realDoc()..remove('completedSessions'); // from before the counter
    final cloud = FakeCloud('u1', doc: doc);
    withStorage({}, cloud, (storage, time) {
      attach(storage, time);
      // Old estimate: 6 harvests × 4 stages + current stage 2.
      expect(storage.completedSessions, 26);
      time.elapse(const Duration(seconds: 2));
      expect(cloud.saves.first['completedSessions'], 26, reason: 'written to the cloud once');

      storage.setFocusMinutes(20);
      time.elapse(const Duration(seconds: 2));
      expect(cloud.saves.last.containsKey('completedSessions'), isFalse, reason: 'only once');
    });
  });

  test('signing out (already signed out of Firebase) uploads nothing and wipes the phone', () {
    final cloud = FakeCloud('u1', doc: realDoc());
    withStorage({}, cloud, (storage, time) {
      attach(storage, time);
      storage.detachUser(push: false);
      time.elapse(const Duration(seconds: 2));
      expect(cloud.saves, isEmpty);
      expect(storage.username, isNot('Necko'));
      expect(storage.completedSessions, 0);
    });
  });
}
