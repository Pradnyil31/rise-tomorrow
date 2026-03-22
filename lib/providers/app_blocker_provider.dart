import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_blocking_service.dart';
import '../providers/settings_provider.dart';
import '../providers/sessions_provider.dart';
import '../models/focus_session.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final appBlockingServiceProvider =
    Provider<AppBlockingService>((ref) => AppBlockingService());

// ─── Permissions State ───────────────────────────────────────────────────────

class PermissionsState {
  final bool hasUsageStats;
  final bool hasOverlay;
  const PermissionsState({this.hasUsageStats = false, this.hasOverlay = false});
  bool get allGranted => hasUsageStats && hasOverlay;
  PermissionsState copyWith({bool? hasUsageStats, bool? hasOverlay}) =>
      PermissionsState(
        hasUsageStats: hasUsageStats ?? this.hasUsageStats,
        hasOverlay: hasOverlay ?? this.hasOverlay,
      );
}

final permissionsProvider =
    StateNotifierProvider<PermissionsNotifier, PermissionsState>((ref) {
  return PermissionsNotifier(ref.read(appBlockingServiceProvider));
});

class PermissionsNotifier extends StateNotifier<PermissionsState> {
  final AppBlockingService _svc;
  PermissionsNotifier(this._svc) : super(const PermissionsState()) {
    refresh();
  }

  Future<void> refresh() async {
    final usage = await _svc.hasUsageStatsPermission();
    final overlay = await _svc.hasOverlayPermission();
    state = PermissionsState(hasUsageStats: usage, hasOverlay: overlay);
  }

  Future<void> requestUsageStats() async {
    await _svc.requestUsageStatsPermission();
    // User has to go to settings and come back — refresh on resume
  }

  Future<void> requestOverlay() async {
    await _svc.requestOverlayPermission();
  }
}

// ─── Blocking State ──────────────────────────────────────────────────────────

class BlockingState {
  final bool isActive;
  final Set<String> selectedPackages;
  final bool isLoading;
  final List<Map<String, dynamic>> installedApps;

  const BlockingState({
    this.isActive = false,
    this.selectedPackages = const {},
    this.isLoading = true,
    this.installedApps = const [],
  });

  BlockingState copyWith({
    bool? isActive,
    Set<String>? selectedPackages,
    bool? isLoading,
    List<Map<String, dynamic>>? installedApps,
  }) =>
      BlockingState(
        isActive: isActive ?? this.isActive,
        selectedPackages: selectedPackages ?? this.selectedPackages,
        isLoading: isLoading ?? this.isLoading,
        installedApps: installedApps ?? this.installedApps,
      );
}

final blockingProvider =
    StateNotifierProvider<BlockingNotifier, BlockingState>((ref) {
  return BlockingNotifier(ref.read(appBlockingServiceProvider), ref);
});

class BlockingNotifier extends StateNotifier<BlockingState> {
  final AppBlockingService _svc;
  final Ref _ref;

  BlockingNotifier(this._svc, this._ref) : super(const BlockingState()) {
    _init();
    
    // Sync schedules when settings change
    _ref.listen(settingsProvider, (_, next) {
      _syncSchedulesToNative(next.schedules);
    });
  }

  Future<void> _init() async {
    final apps = await _svc.getInstalledApps();
    final active = await _svc.isBlockingActive();
    
    final prefs = await SharedPreferences.getInstance();
    final savedPkgs = prefs.getStringList('selected_blocked_pkgs') ?? [];
    
    state = state.copyWith(
        installedApps: apps, 
        isActive: active, 
        isLoading: false,
        selectedPackages: savedPkgs.toSet()
    );
    
    _syncSchedulesToNative(_ref.read(settingsProvider).schedules);
  }

  void togglePackage(String pkg) {
    if (state.isActive) return; // Feature 6: prevent deselection
    
    final set = Set<String>.from(state.selectedPackages);
    if (set.contains(pkg)) {
      set.remove(pkg);
    } else {
      set.add(pkg);
    }
    state = state.copyWith(selectedPackages: set);
    
    // Save to SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('selected_blocked_pkgs', set.toList());
    });
    
    _syncSchedulesToNative(_ref.read(settingsProvider).schedules);
  }

  void _syncSchedulesToNative(List<dynamic> schedules) {
    final schedsList = schedules.map((e) => e.toJson() as Map<String, dynamic>).toList();
    _svc.updateSchedules(schedsList, state.selectedPackages.toList());
  }

  DateTime? _blockStartTime;

  Future<void> startBlocking() async {
    if (state.selectedPackages.isEmpty) return;
    await _svc.startBlocking(packageNames: state.selectedPackages.toList());
    _blockStartTime = DateTime.now();
    state = state.copyWith(isActive: true);
  }

  Future<void> stopBlocking() async {
    await _svc.stopBlocking();
    if (_blockStartTime != null) {
      final now = DateTime.now();
      final duration = now.difference(_blockStartTime!).inMinutes;
      if (duration > 0) {
        final session = FocusSession(
          id: '',
          userId: '',
          type: SessionType.custom,
          sessionName: 'App Blocker Focus',
          startTime: _blockStartTime!,
          endTime: now,
          duration: duration,
          actualDuration: duration,
          completed: true,
          createdAt: now,
        );
        _ref.read(saveSessionProvider)(session);
      }
      _blockStartTime = null;
    }
    state = state.copyWith(isActive: false);
  }

  Future<void> refresh() => _init();
}
