import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/tasks_provider.dart';
import '../../models/task.dart';
import '../../widgets/tasks/task_card.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final filter = ref.watch(taskFilterProvider);
    final notifier = ref.read(tasksProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/tasks/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: TaskFilter.values.map((f) {
                final labels = {
                  TaskFilter.all: 'All',
                  TaskFilter.today: 'Today',
                  TaskFilter.highPriority: 'High Priority',
                  TaskFilter.overdue: 'Overdue',
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(labels[f]!),
                    selected: filter == f,
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    checkmarkColor: AppColors.primary,
                    onSelected: (_) =>
                        ref.read(taskFilterProvider.notifier).state = f,
                  ),
                );
              }).toList(),
            ),
          ),

          // Task list
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) {
                final tasks = notifier.filtered;
                if (tasks.isEmpty) {
                  return _EmptyTasks(filter: filter);
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 80),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) => TaskCard(
                    task: tasks[i],
                    onComplete: () => notifier.completeTask(tasks[i].id),
                    onDelete: () => notifier.deleteTask(tasks[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/tasks/add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Task',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  final TaskFilter filter;
  const _EmptyTasks({required this.filter});

  @override
  Widget build(BuildContext context) {
    final messages = {
      TaskFilter.all: "No tasks yet.\nTap + to add your first task!",
      TaskFilter.today: "No tasks due today. Enjoy your day! 🌤️",
      TaskFilter.highPriority: "No high priority tasks. Great job! ✅",
      TaskFilter.overdue: "No overdue tasks. You're on top of things! 🎉",
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.assignment_outlined,
              size: 64, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          Text(
            messages[filter]!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }
}
