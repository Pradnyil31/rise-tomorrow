import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';

final firebaseServiceProvider =
    Provider<FirebaseService>((ref) => FirebaseService());

enum TaskFilter { all, today, highPriority, overdue, completed }

final taskFilterProvider = StateProvider<TaskFilter>((ref) => TaskFilter.all);

final tasksProvider =
    StateNotifierProvider<TasksNotifier, AsyncValue<List<Task>>>((ref) {
  return TasksNotifier(ref);
});

class TasksNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final Ref _ref;
  final _uuid = const Uuid();

  TasksNotifier(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen<AsyncValue>(authStateProvider, (_, next) {
      next.whenData((user) {
        if (user != null) _subscribe(user.uid);
      });
    }, fireImmediately: true);
  }

  void _subscribe(String uid) {
    _ref.read(firebaseServiceProvider).watchTasks(uid).listen(
      (tasks) => state = AsyncValue.data(tasks),
      onError: (e, st) => state = AsyncValue.error(e, st),
    );
  }

  List<Task> get filtered {
    final tasks = state.valueOrNull ?? [];
    final filter = _ref.read(taskFilterProvider);
    switch (filter) {
      case TaskFilter.all:
        return tasks;
      case TaskFilter.today:
        return tasks.where((t) {
          if (t.dueDate == null) return false;
          final now = DateTime.now();
          return t.dueDate!.year == now.year &&
              t.dueDate!.month == now.month &&
              t.dueDate!.day == now.day;
        }).toList();
      case TaskFilter.highPriority:
        return tasks.where((t) => t.priority == Priority.high).toList();
      case TaskFilter.overdue:
        return tasks.where((t) => t.isOverdue).toList();
      case TaskFilter.completed:
        return tasks.where((t) => t.isCompleted).toList();
    }
  }

  Future<void> addTask({
    required String title,
    String? description,
    DateTime? dueDate,
    Priority priority = Priority.medium,
    List<String> tags = const [],
    List<Subtask> subtasks = const [],
  }) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final task = Task(
      id: _uuid.v4(),
      userId: user.uid,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      tags: tags,
      subtasks: subtasks,
      createdAt: DateTime.now(),
    );

    await _ref.read(firebaseServiceProvider).addTask(task);
    if (task.dueDate != null) {
      NotificationService().scheduleTaskReminder(task);
    }
  }

  Future<void> completeTask(String id) async {
    final tasks = state.valueOrNull ?? [];
    final task = tasks.firstWhere((t) => t.id == id);
    final updated = task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
    );
    await _ref.read(firebaseServiceProvider).updateTask(updated);
    NotificationService().cancelTaskReminder(id);
  }

  Future<void> deleteTask(String id) async {
    await _ref.read(firebaseServiceProvider).deleteTask(id);
    NotificationService().cancelTaskReminder(id);
  }

  Future<void> updateTask(Task task) async {
    await _ref.read(firebaseServiceProvider).updateTask(task);
    if (task.dueDate != null && !task.isCompleted) {
      NotificationService().scheduleTaskReminder(task);
    } else {
      NotificationService().cancelTaskReminder(task.id);
    }
  }
}
