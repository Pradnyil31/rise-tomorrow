import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/focus_session.dart';
import '../providers/auth_provider.dart';
import '../providers/tasks_provider.dart';

final sessionsProvider = StreamProvider<List<FocusSession>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(firebaseServiceProvider).watchSessions(user.uid, limitDays: 30);
});

final saveSessionProvider = Provider<Future<void> Function(FocusSession)>((ref) {
  return (FocusSession session) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    
    final updatedSession = FocusSession(
      id: session.id.isEmpty ? const Uuid().v4() : session.id,
      userId: user.uid,
      type: session.type,
      sessionName: session.sessionName,
      startTime: session.startTime,
      endTime: session.endTime,
      duration: session.duration,
      actualDuration: session.actualDuration,
      completed: session.completed,
      autoStart: session.autoStart,
      notes: session.notes,
      blockedApps: session.blockedApps,
      createdAt: session.createdAt,
    );
    
    await ref.read(firebaseServiceProvider).saveFocusSession(updatedSession);
  };
});
