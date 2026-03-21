import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/timer_service.dart';
import '../models/focus_session.dart';
import 'sessions_provider.dart';

final stopwatchProvider =
    ChangeNotifierProvider<StopwatchService>((ref) => StopwatchService());

final countdownProvider =
    ChangeNotifierProvider<CountdownTimerService>((ref) {
  final cd = CountdownTimerService();
  cd.onSessionCompleted = (duration) {
    final session = FocusSession(
      id: '',
      userId: '',
      type: SessionType.custom,
      sessionName: 'Focus ($duration min)',
      startTime: DateTime.now().subtract(Duration(minutes: duration)),
      endTime: DateTime.now(),
      duration: duration,
      actualDuration: duration,
      completed: true,
      createdAt: DateTime.now(),
    );
    ref.read(saveSessionProvider)(session);
  };
  return cd;
});

final pomodoroProvider =
    ChangeNotifierProvider<PomodoroService>((ref) {
  final pom = PomodoroService();
  pom.onSessionCompleted = (duration, phase) {
    if (phase == PomodoroPhase.work) {
      final session = FocusSession(
        id: '',
        userId: '',
        type: SessionType.deepWork,
        sessionName: 'Pomodoro Work',
        startTime: DateTime.now().subtract(Duration(minutes: duration)),
        endTime: DateTime.now(),
        duration: duration,
        actualDuration: duration,
        completed: true,
        createdAt: DateTime.now(),
      );
      ref.read(saveSessionProvider)(session);
    }
  };
  return pom;
});
