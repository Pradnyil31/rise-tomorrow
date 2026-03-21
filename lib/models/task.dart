enum Priority { low, medium, high }

extension PriorityX on Priority {
  String get label => name[0].toUpperCase() + name.substring(1);
}

enum TaskStatus { pending, completed, archived }

class Subtask {
  final String title;
  final bool completed;

  const Subtask({required this.title, this.completed = false});

  Subtask copyWith({String? title, bool? completed}) =>
      Subtask(title: title ?? this.title, completed: completed ?? this.completed);

  Map<String, dynamic> toJson() => {'title': title, 'completed': completed};
  factory Subtask.fromJson(Map<String, dynamic> j) =>
      Subtask(title: j['title'] as String, completed: j['completed'] as bool? ?? false);
}

class Task {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final Priority priority;
  final TaskStatus status;
  final List<String> tags;
  final List<Subtask> subtasks;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int sortOrder;

  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.dueDate,
    this.priority = Priority.medium,
    this.status = TaskStatus.pending,
    this.tags = const [],
    this.subtasks = const [],
    required this.createdAt,
    this.completedAt,
    this.sortOrder = 0,
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status == TaskStatus.pending;

  Task copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    Priority? priority,
    TaskStatus? status,
    List<String>? tags,
    List<Subtask>? subtasks,
    DateTime? completedAt,
    int? sortOrder,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'description': description,
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority.name,
        'status': status.name,
        'tags': tags,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'sortOrder': sortOrder,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        userId: j['userId'] as String? ?? '',
        title: j['title'] as String,
        description: j['description'] as String?,
        dueDate: j['dueDate'] != null
            ? DateTime.tryParse(j['dueDate'] as String)
            : null,
        priority: Priority.values.firstWhere(
          (e) => e.name == j['priority'],
          orElse: () => Priority.medium,
        ),
        status: TaskStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => TaskStatus.pending,
        ),
        tags: List<String>.from(j['tags'] as List? ?? []),
        subtasks: (j['subtasks'] as List? ?? [])
            .map((s) => Subtask.fromJson(s as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        completedAt: j['completedAt'] != null
            ? DateTime.tryParse(j['completedAt'] as String)
            : null,
        sortOrder: j['sortOrder'] as int? ?? 0,
      );
}
