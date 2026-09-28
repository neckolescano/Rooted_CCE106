import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Talks to Cloud Firestore for ONE signed-in user. All of that user's
/// data lives under a single document, `users/{uid}`, plus a
/// `sessions` subcollection with one small document per study session:
///
///   users/{uid}                 profile + stats + plant + notes
///   users/{uid}/sessions/{id}   one document per finished/abandoned session
class CloudService {
  CloudService(this.uid);

  final String uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// Returns the saved data, or null if this user has no document yet
  /// (i.e. a brand-new account). Throws if the request itself fails
  /// (offline with nothing cached) so the caller can tell "new user"
  /// apart from "couldn't reach the database".
  Future<Map<String, dynamic>?> loadUser() async {
    final snap = await _userDoc.get().timeout(const Duration(seconds: 8));
    if (!snap.exists) return null;

    final data = Map<String, dynamic>.from(snap.data()!);
    final created = data['createdAt'];
    if (created is Timestamp) {
      data['memberSinceYear'] = created.toDate().year;
    }
    return data;
  }

  Future<void> saveUser(Map<String, dynamic> data, {bool isNew = false}) {
    return _userDoc.set({
      ...data,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Adds one document to the sessions log. Never throws — a failed log
  /// entry shouldn't interrupt studying.
  Future<void> logSession({required bool completed, required int seconds}) async {
    try {
      await _userDoc.collection('sessions').add({
        'completed': completed,
        'seconds': seconds,
        'endedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Session log failed: $error');
    }
  }
}
