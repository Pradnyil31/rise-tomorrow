import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/timer_provider.dart';
import '../../services/timer_service.dart';
import '../../services/notification_service.dart';
import '../../utils/extensions.dart';
import '../../widgets/timer/circular_timer_painter.dart';

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen>
    with TickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Timer'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Stopwatch'),
            Tab(text: 'Timer'),
            Tab(text: 'Pomodoro'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Color(0xFF6B7280),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _StopwatchTab(),
          _CountdownTab(),
          _PomodoroTab(),
        ],
      ),
    );
  }
}

// ─── Stopwatch Tab ────────────────────────────────────────────────────────────

class _StopwatchTab extends ConsumerWidget {
  const _StopwatchTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sw = ref.watch(stopwatchProvider);
    return Column(
      children: [
        const SizedBox(height: 40),
        // Big display
        Text(
          sw.elapsed.formattedWithMs,
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w200,
            letterSpacing: 3,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 40),
        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlBtn(
              icon: Icons.flag_outlined,
              color: AppColors.info,
              onTap: sw.isRunning ? sw.recordLap : null,
            ),
            const SizedBox(width: 24),
            _BigPlayBtn(
              isRunning: sw.isRunning,
              color: AppColors.primary,
              onTap: sw.isRunning ? sw.pause : sw.start,
            ),
            const SizedBox(width: 24),
            _ControlBtn(
              icon: Icons.refresh_rounded,
              color: AppColors.error,
              onTap: sw.isRunning ? null : sw.reset,
            ),
          ],
        ),
        // Laps
        if (sw.laps.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: sw.laps.length,
              itemBuilder: (ctx, i) {
                final lap = sw.laps[sw.laps.length - 1 - i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      '${lap.number}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                  title: Text(lap.elapsed.formattedWithMs),
                  trailing: Text(
                    '+ ${lap.lapTime.formatted}',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13),
                  ),
                );
              },
            ),
          ),
        ] else
          const Spacer(),
      ],
    );
  }
}

// ─── Countdown Tab ────────────────────────────────────────────────────────────

class _CountdownTab extends ConsumerWidget {
  const _CountdownTab();

  static const _presets = [5, 15, 25, 45, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cd = ref.watch(countdownProvider);

    // Notify on complete
    if (cd.phase == TimerPhase.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService().showTimerComplete();
      });
    }

    final progressColor = timerProgressColor(cd.progress);

    return Column(
      children: [
        const SizedBox(height: 32),
        // Circular timer
        SizedBox(
          width: 220,
          height: 220,
          child: CustomPaint(
            painter: CircularTimerPainter(
              progress: cd.phase == TimerPhase.idle ? 1.0 : cd.progress,
              progressColor: progressColor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatSeconds(cd.remainingSeconds),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 2,
                    ),
                  ),
                  if (cd.phase == TimerPhase.completed)
                    const Text('Done! 🎉',
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Presets
        if (cd.phase == TimerPhase.idle || cd.phase == TimerPhase.completed)
          Wrap(
            spacing: 10,
            children: _presets
                .map((min) => ActionChip(
                      label: Text('$min min'),
                      onPressed: () =>
                          ref.read(countdownProvider).setDuration(min),
                    ))
                .toList(),
          ),
        const SizedBox(height: 28),
        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlBtn(
              icon: Icons.refresh_rounded,
              color: AppColors.error,
              onTap: cd.reset,
            ),
            const SizedBox(width: 24),
            _BigPlayBtn(
              isRunning: cd.phase == TimerPhase.running,
              color: progressColor,
              onTap: () {
                if (cd.phase == TimerPhase.running) {
                  ref.read(countdownProvider).pause();
                } else if (cd.phase != TimerPhase.completed) {
                  ref.read(countdownProvider).start();
                } else {
                  ref.read(countdownProvider).reset();
                }
              },
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

// ─── Pomodoro Tab ─────────────────────────────────────────────────────────────

class _PomodoroTab extends ConsumerWidget {
  const _PomodoroTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pom = ref.watch(pomodoroProvider);
    final isWork = pom.phase == PomodoroPhase.work;

    final phaseColor = isWork ? AppColors.primary : AppColors.success;
    final phaseLabel = switch (pom.phase) {
      PomodoroPhase.work => 'Deep Work',
      PomodoroPhase.shortBreak => 'Short Break',
      PomodoroPhase.longBreak => 'Long Break',
    };

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Phase badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: phaseColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(phaseLabel,
                style: TextStyle(
                    color: phaseColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
          const SizedBox(height: 20),

          // Circular timer
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: CircularTimerPainter(
                progress: pom.timerPhase == TimerPhase.idle
                    ? 1.0
                    : pom.progress,
                progressColor: phaseColor,
              ),
              child: Center(
                child: Text(
                  formatSeconds(pom.remainingSeconds),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Session dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pom.sessionsBeforeLongBreak, (i) {
              final done = i < pom.completedSessions % pom.sessionsBeforeLongBreak;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: done ? 28 : 20,
                height: 10,
                decoration: BoxDecoration(
                  color: done ? AppColors.primary : AppColors.outlineColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            '${pom.completedSessions} sessions completed',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),

          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlBtn(
                icon: Icons.refresh_rounded,
                color: AppColors.error,
                onTap: pom.reset,
              ),
              const SizedBox(width: 24),
              _BigPlayBtn(
                isRunning: pom.timerPhase == TimerPhase.running,
                color: phaseColor,
                onTap: () {
                  if (pom.timerPhase == TimerPhase.running) {
                    ref.read(pomodoroProvider).pause();
                  } else {
                    ref.read(pomodoroProvider).start();
                  }
                },
              ),
              const SizedBox(width: 24),
              _ControlBtn(
                icon: Icons.skip_next_rounded,
                color: AppColors.warning,
                onTap: pom.skipPhase,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Shared Controls ──────────────────────────────────────────────────────────

class _BigPlayBtn extends StatelessWidget {
  final bool isRunning;
  final Color color;
  final VoidCallback? onTap;

  const _BigPlayBtn(
      {required this.isRunning, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ControlBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.3 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}
