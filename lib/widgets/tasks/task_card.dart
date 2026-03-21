import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../utils/extensions.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.onComplete,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: Key(task.id),
        background: _swipeBackground(
          color: AppColors.success,
          icon: Icons.check_rounded,
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _swipeBackground(
          color: AppColors.error,
          icon: Icons.delete_rounded,
          alignment: Alignment.centerRight,
        ),
        onDismissed: (direction) {
          if (direction == DismissDirection.startToEnd) {
            onComplete?.call();
          } else {
            onDelete?.call();
          }
        },
        child: InkWell(
          onTap: onTap ?? () {
            if (task.description?.isNotEmpty == true) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(task.title),
                  content: SingleChildScrollView(
                    child: Text(task.description!, style: const TextStyle(fontSize: 15, height: 1.5)),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
                  ],
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.outlineColor,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                GestureDetector(
                  onTap: onComplete,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? AppColors.success
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isCompleted
                            ? AppColors.success
                            : (isDark
                                ? AppColors.surfaceVariantDark
                                : AppColors.outlineColor),
                        width: 2,
                      ),
                    ),
                    child: task.isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? (isDark
                                  ? AppColors.surfaceVariantDark
                                  : const Color(0xFF9CA3AF))
                              : null,
                        ),
                      ),
                      if (task.description != null &&
                          task.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _PriorityChip(priority: task.priority),
                          const SizedBox(width: 8),
                          if (task.dueDate != null) ...[
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: task.isOverdue
                                  ? AppColors.error
                                  : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              task.dueDate!.relative,
                              style: TextStyle(
                                fontSize: 12,
                                color: task.isOverdue
                                    ? AppColors.error
                                    : const Color(0xFF6B7280),
                                fontWeight: task.isOverdue
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                          Builder(
                            builder: (context) {
                              final validSubtasks = task.subtasks.where((s) => s.title.trim().isNotEmpty).toList();
                              if (validSubtasks.isNotEmpty) {
                                return Expanded(
                                  child: Row(
                                    children: [
                                      const Spacer(),
                                      Text(
                                        '${validSubtasks.where((s) => s.completed).length}/${validSubtasks.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required Color color,
    required IconData icon,
    required AlignmentGeometry alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final Priority priority;
  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: priority.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: priority.color,
        ),
      ),
    );
  }
}
