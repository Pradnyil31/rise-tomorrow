import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/focus_session.dart';

// ─── Stopwatch Service ────────────────────────────────────────────────────────

class StopwatchService extends ChangeNotifier {
  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;
  final List<_LapRecord> _laps = [];

  Duration get elapsed => _sw.elapsed;
  bool get isRunning => _sw.isRunning;
  List<_LapRecord> get laps => List.unmodifiable(_laps);

  void start() {
    _sw.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  void pause() {
    _sw.stop();
    _ticker?.cancel();
    notifyListeners();
  }

  void reset() {
    _sw.reset();
    _ticker?.cancel();
    _laps.clear();
    notifyListeners();
  }

  void recordLap() {
    if (!_sw.isRunning) return;
    final prev = _laps.isEmpty ? Duration.zero : _laps.last.elapsed;
    _laps.add(_LapRecord(
      number: _laps.length + 1,
      elapsed: _sw.elapsed,
      lapTime: _sw.elapsed - prev,
    ));
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

class _LapRecord {
  final int number;
  final Duration elapsed;
  final Duration lapTime;
  _LapRecord({required this.number, required this.elapsed, required this.lapTime});
}

// ─── Countdown Timer Service ──────────────────────────────────────────────────

enum TimerPhase { idle, running, paused, completed }

class CountdownTimerService extends ChangeNotifier {
  int _totalSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  TimerPhase _phase = TimerPhase.idle;
  Timer? _timer;
  void Function(int durationMins)? onSessionCompleted;

  int get totalSeconds => _totalSeconds;
  int get remainingSeconds => _remainingSeconds;
  TimerPhase get phase => _phase;
  double get progress =>
      _totalSeconds == 0 ? 0 : _remainingSeconds / _totalSeconds;

  void setDuration(int minutes) {
    if (_phase == TimerPhase.running) return;
    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
    _phase = TimerPhase.idle;
    notifyListeners();
  }

  void start() {
    if (_phase == TimerPhase.completed) return;
    _phase = TimerPhase.running;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _phase = TimerPhase.completed;
        onSessionCompleted?.call(_totalSeconds ~/ 60);
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _phase = TimerPhase.paused;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _remainingSeconds = _totalSeconds;
    _phase = TimerPhase.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ─── Pomodoro Service ─────────────────────────────────────────────────────────

enum PomodoroPhase { work, shortBreak, longBreak }

class PomodoroService extends ChangeNotifier {
  int workMinutes = 25;
  int shortBreakMinutes = 5;
  int longBreakMinutes = 15;
  int sessionsBeforeLongBreak = 4;

  int completedSessions = 0;
  PomodoroPhase _phase = PomodoroPhase.work;
  int _remainingSeconds = 25 * 60;
  TimerPhase _timerPhase = TimerPhase.idle;
  Timer? _timer;
  void Function(int durationMins, PomodoroPhase phase)? onSessionCompleted;

  PomodoroPhase get phase => _phase;
  int get remainingSeconds => _remainingSeconds;
  TimerPhase get timerPhase => _timerPhase;
  int get currentDurationSeconds {
    switch (_phase) {
      case PomodoroPhase.work:
        return workMinutes * 60;
      case PomodoroPhase.shortBreak:
        return shortBreakMinutes * 60;
      case PomodoroPhase.longBreak:
        return longBreakMinutes * 60;
    }
  }

  double get progress =>
      currentDurationSeconds == 0 ? 0 : _remainingSeconds / currentDurationSeconds;

  void start() {
    if (_timerPhase == TimerPhase.running) return;
    _timerPhase = TimerPhase.running;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _completePhase();
      }
    });
    notifyListeners();
  }

  void _completePhase() {
    _timer?.cancel();
    _timerPhase = TimerPhase.completed;
    onSessionCompleted?.call(currentDurationSeconds ~/ 60, _phase);
    
    if (_phase == PomodoroPhase.work) {
      completedSessions++;
      if (completedSessions % sessionsBeforeLongBreak == 0) {
        _phase = PomodoroPhase.longBreak;
        _remainingSeconds = longBreakMinutes * 60;
      } else {
        _phase = PomodoroPhase.shortBreak;
        _remainingSeconds = shortBreakMinutes * 60;
      }
    } else {
      _phase = PomodoroPhase.work;
      _remainingSeconds = workMinutes * 60;
    }
    notifyListeners();
  }

  void skipPhase() {
    _timer?.cancel();
    _completePhase();
  }

  void pause() {
    _timer?.cancel();
    _timerPhase = TimerPhase.paused;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    completedSessions = 0;
    _phase = PomodoroPhase.work;
    _remainingSeconds = workMinutes * 60;
    _timerPhase = TimerPhase.idle;
    notifyListeners();
  }

  void updateSettings({
    int? work,
    int? shortBreak,
    int? longBreak,
    int? sessions,
  }) {
    workMinutes = work ?? workMinutes;
    shortBreakMinutes = shortBreak ?? shortBreakMinutes;
    longBreakMinutes = longBreak ?? longBreakMinutes;
    sessionsBeforeLongBreak = sessions ?? sessionsBeforeLongBreak;
    reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
