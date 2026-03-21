import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/tasks/task_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final analytics = ref.watch(analyticsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final profile = profileAsync.valueOrNull;
    final displayName = profile?.displayName.split(' ').first ?? 'there';
    final allTasks = tasksAsync.valueOrNull ?? [];
    final pending = allTasks.where((t) => !t.isCompleted).take(3).toList();
    final completedCount = allTasks.where((t) => t.isCompleted).length;
    final totalCount = allTasks.length;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: false,
            floating: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${greetingByTime()},',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: Text(
                        displayName.isEmpty
                            ? '?'
                            : displayName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Today's Progress ──────────────────────────────────────
                  _SectionCard(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                backgroundColor: AppColors.outlineColor,
                                color: AppColors.primary,
                                strokeWidth: 6,
                                strokeCap: StrokeCap.round,
                              ),
                              Center(
                                child: Text(
                                  '${(progress * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Today's Progress",
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              '$completedCount of $totalCount tasks done',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 13),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '${analytics.currentStreak} 🔥',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Quick Actions ─────────────────────────────────────────
                  const Text('Quick Actions',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _QuickAction(
                        icon: Icons.timer_rounded,
                        label: 'Focus',
                        color: AppColors.primary,
                        onTap: () => context.go('/timer'),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.block_rounded,
                        label: 'Block',
                        color: AppColors.error,
                        onTap: () => context.go('/blocker'),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.add_task_rounded,
                        label: 'Add Task',
                        color: AppColors.success,
                        onTap: () => context.go('/tasks/add'),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.bar_chart_rounded,
                        label: 'Stats',
                        color: AppColors.warning,
                        onTap: () => context.go('/analytics'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ─── Upcoming Tasks ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Upcoming Tasks',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      TextButton(
                        onPressed: () => context.go('/tasks'),
                        child: const Text('View all →'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  if (pending.isEmpty)
                    _EmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      message: "You're all caught up! 🎉",
                    )
                  else
                    ...pending.map((task) => TaskCard(
                          task: task,
                          onComplete: () => ref
                              .read(tasksProvider.notifier)
                              .completeTask(task.id),
                          onDelete: () => ref
                              .read(tasksProvider.notifier)
                              .deleteTask(task.id),
                          onTap: () => context.go('/tasks'),
                        )),

                  const SizedBox(height: 20),

                  // ─── Daily Insight ─────────────────────────────────────────
                  _InsightCard(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final _tips = const [
    '💡 Try a 25-min focus session. Pomodoro is proven to boost productivity.',
    '🧠 Taking regular breaks actually improves focus quality.',
    '🎯 Having 3 priority tasks per day beats a long to-do list.',
    '📵 Blocking social media for 1 hour can save 2 hours of distraction.',
    '⏰ Peak productivity for most people is 9–11 AM. Schedule deep work then!',
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Insight',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(tip,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
