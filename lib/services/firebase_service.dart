import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../models/focus_session.dart';
import '../models/user_profile.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseService() {
    // Enable offline persistence
    _db.settings = const Settings(persistenceEnabled: true);
  }

  // ─── Tasks ───────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _tasksCol() =>
      _db.collection('tasks');

  Stream<List<Task>> watchTasks(String userId) {
    return _tasksCol()
        .where('userId', isEqualTo: userId)
        .where('status', whereNotIn: ['archived'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Task.fromJson({...d.data(), 'id': d.id})).toList());
  }

  Future<void> addTask(Task task) async {
    await _tasksCol().doc(task.id).set(task.toJson());
  }

  Future<void> updateTask(Task task) async {
    await _tasksCol().doc(task.id).update(task.toJson());
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksCol().doc(taskId).delete();
  }

  // ─── Focus Sessions ───────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _sessionsCol() =>
      _db.collection('focusSessions');

  Future<void> saveFocusSession(FocusSession session) async {
    await _sessionsCol().doc(session.id).set(session.toJson());
  }

  Stream<List<FocusSession>> watchSessions(String userId,
      {int limitDays = 30}) {
    final since =
        DateTime.now().subtract(Duration(days: limitDays)).toIso8601String();
    return _sessionsCol()
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThan: since)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FocusSession.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  // ─── User Profile ─────────────────────────────────────────────────────────

  Future<void> saveUserProfile(UserProfile profile) async {
    await _db
        .collection('users')
        .doc(profile.uid)
        .set(profile.toJson(), SetOptions(merge: true));
  }

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) =>
            snap.exists ? UserProfile.fromJson(snap.data()!) : null);
  }

  // ─── Blocked Apps ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchBlockedApps(String userId) async {
    final snap = await _db
        .collection('blockedApps')
        .where('userId', isEqualTo: userId)
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  Future<void> saveBlockedApps(
      String userId, List<Map<String, dynamic>> apps) async {
    final batch = _db.batch();
    final col = _db.collection('blockedApps');
    for (final app in apps) {
      final ref = col.doc('${userId}_${app['appPackage']}');
      batch.set(ref, {...app, 'userId': userId});
    }
    await batch.commit();
  }
}
