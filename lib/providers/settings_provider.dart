import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../providers/tasks_provider.dart';
import 'sessions_provider.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  // Initialize from loaded profile if available
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return SettingsNotifier(ref, profile?.settings ?? const UserSettings());
});

class SettingsNotifier extends StateNotifier<UserSettings> {
  final Ref _ref;

  SettingsNotifier(this._ref, UserSettings initial) : super(initial) {
    // Auto-sync when profile loads
    _ref.listen(userProfileProvider, (_, next) {
      next.whenData((profile) {
        if (profile != null) state = profile.settings;
      });
    });
  }

  Future<void> toggleDarkMode() async => _update(state.copyWith(darkMode: !state.darkMode));
  Future<void> toggleNotifications() async => _update(state.copyWith(notifications: !state.notifications));
  Future<void> toggleBiometric() async => _update(state.copyWith(biometricAuth: !state.biometricAuth));
  Future<void> setFocusDuration(int minutes) async =>
      _update(state.copyWith(defaultFocusDuration: minutes));

  Future<void> addSchedule(BlockSchedule schedule) async {
    final List<BlockSchedule> list = List.from(state.schedules)..add(schedule);
    await _update(state.copyWith(schedules: list));
  }

  Future<void> updateSchedule(BlockSchedule schedule) async {
    final List<BlockSchedule> list = state.schedules.map((s) => s.id == schedule.id ? schedule : s).toList();
    await _update(state.copyWith(schedules: list));
  }

  Future<void> removeSchedule(String id) async {
    final List<BlockSchedule> list = state.schedules.where((s) => s.id != id).toList();
    await _update(state.copyWith(schedules: list));
  }

  Future<void> toggleSchedule(String id) async {
    final List<BlockSchedule> list = state.schedules.map((s) {
      if (s.id == id) return s.copyWith(isEnabled: !s.isEnabled);
      return s;
    }).toList();
    await _update(state.copyWith(schedules: list));
  }

  Future<void> _update(UserSettings settings) async {
    state = settings;
    final profile = _ref.read(userProfileProvider).valueOrNull;
    if (profile != null) {
      final updated = profile.copyWith(settings: settings);
      await _ref.read(firebaseServiceProvider).saveUserProfile(updated);
    }
  }
}

// ─── Analytics ───────────────────────────────────────────────────────────────

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  return AnalyticsNotifier(ref);
});

class AnalyticsState {
  final int totalFocusMinutesToday;
  final int completedTasksTotal;
  final int currentStreak;
  final List<double> weeklyFocusMinutes; // last 7 days
  final double productivityScore;

  const AnalyticsState({
    this.totalFocusMinutesToday = 0,
    this.completedTasksTotal = 0,
    this.currentStreak = 0,
    this.weeklyFocusMinutes = const [0, 0, 0, 0, 0, 0, 0],
    this.productivityScore = 0.0,
  });
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final Ref _ref;

  AnalyticsNotifier(this._ref) : super(const AnalyticsState()) {
    _compute();
    _ref.listen(tasksProvider, (_, __) => _compute());
    _ref.listen(sessionsProvider, (_, __) => _compute());
  }

  void _compute() {
    final tasks = _ref.read(tasksProvider).valueOrNull ?? [];
    final completed = tasks.where((t) => t.isCompleted).length;

    final sessions = _ref.read(sessionsProvider).valueOrNull ?? [];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int focusToday = 0;
    
    for (var s in sessions) {
      final sDate = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      if (sDate == today) {
        focusToday += s.actualDuration;
      }
    }

    List<double> weekly = List.filled(7, 0.0);
    for (var s in sessions) {
      final sDate = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      final daysAgo = today.difference(sDate).inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        weekly[6 - daysAgo] += s.actualDuration.toDouble();
      }
    }

    int streak = 0;
    DateTime checkDate = today;
    while (true) {
      bool hasFocus = sessions.any((s) {
        final sDate = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
        return sDate == checkDate;
      });
      if (hasFocus) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        if (checkDate == today) {
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // Productivity Score calculation
    // Max 100. Base: (focusToday / 120) * 80 + (completed * 20)
    double score = 0.0;
    if (focusToday > 0 || completed > 0) {
      score = ((focusToday / 120.0) * 80.0) + (completed * 10.0);
      if (score > 100.0) score = 100.0;
    }

    state = AnalyticsState(
      completedTasksTotal: completed,
      totalFocusMinutesToday: focusToday,
      currentStreak: streak,
      weeklyFocusMinutes: weekly,
      productivityScore: score,
    );
  }

  void refresh() => _compute();
}
