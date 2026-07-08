import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/pages/add_entry_page.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/pages/unified_text_entry.dart';
import 'package:yattta/presentation/pages/task_details.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';

class TasksPage extends ConsumerWidget {
  final VoidCallback? onMenuPressed;

  const TasksPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(activeTasksProvider);
    final logsAsync = ref.watch(todayLogsProvider);
    final remindersAsync = ref.watch(activeRemindersProvider);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Tasks'),
        prefixes: [
          if (onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: onMenuPressed!,
            ),
        ],
      ),
      child: Stack(
        children: [
          tasksAsync.when(
            data: (tasks) => logsAsync.when(
              data: (logs) => remindersAsync.when(
                data: (reminders) => _buildTaskList(context, ref, tasks, logs, reminders),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading reminders: $err')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading logs: $err')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading tasks: $err')),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FButton.icon(
              onPress: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddEntryPage(type: EntryType.task)),
              ),
              child: const Icon(FLucideIcons.plus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, WidgetRef ref, List<Task> allTasks, List<TaskLog> logs, List<Reminder> allReminders) {
    if (allTasks.isEmpty) {
      return const Center(child: Text('No active tasks. Add one!'));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todayTasks = <Task>[];
    final noRemindersTasks = <Task>[];
    final futureTasks = <Task>[];

    for (final task in allTasks) {
      final taskReminders = allReminders.where((r) => r.taskId == task.id).toList();
      if (taskReminders.isEmpty) {
        noRemindersTasks.add(task);
      } else if (taskReminders.any((r) => r.remindAt.isBefore(tomorrow))) {
        todayTasks.add(task);
      } else {
        futureTasks.add(task);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (todayTasks.isNotEmpty)
            _buildTaskGroup(context, ref, 'Today', todayTasks, logs),
          if (noRemindersTasks.isNotEmpty)
            _buildTaskGroup(context, ref, 'No reminders set', noRemindersTasks, logs),
          if (futureTasks.isNotEmpty)
            _buildTaskGroup(context, ref, 'Future', futureTasks, logs),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildTaskGroup(BuildContext context, WidgetRef ref, String title, List<Task> tasks, List<TaskLog> logs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FTheme.of(context).typography.body.sm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: FTheme.of(context).colors.mutedForeground,
                ),
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            onReorderItem: (oldIndex, newIndex) {
              final item = tasks.removeAt(oldIndex);
              tasks.insert(newIndex, item);
              ref.read(tasksDaoProvider).updatePositions(
                    tasks.map((t) => t.id).toList(),
                  );
            },
            itemBuilder: (context, index) {
              final task = tasks[index];
              final log = logs.where((l) => l.taskId == task.id).firstOrNull;
              return _buildTaskTile(context, ref, task, log, index);
            },
          ),
        ],
      ),
    );
  }

  FTile _buildTaskTile(BuildContext context, WidgetRef ref, Task task, TaskLog? log, int index) {
    final isDone = log?.status == TaskLogStatus.done;
    final isSkipped = log?.status == TaskLogStatus.skipped;

    return FTile(
      key: ValueKey(task.id),
      onPress: () async {
        final tags = await ref.read(tagsDaoProvider).getTagsForTask(task.id);
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TaskDetailsPage(
                task: task,
                tags: tags,
              ),
            ),
          );
        }
      },
      title: Row(
        children: [
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                decoration: isDone ? TextDecoration.lineThrough : null,
                color: isSkipped || isDone ? FTheme.of(context).colors.mutedForeground : null,
              ),
            ),
          ),
          StreamBuilder<int>(
            stream: ref.read(pomodoroSessionsDaoProvider).watchCountForTask(task.id),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FBadge(
                  variant: FBadgeVariant.secondary,
                  child: Text('$count 🍅'),
                ),
              );
            },
          ),
        ],
      ),
      subtitle: FutureBuilder<List<Tag>>(
        future: ref.read(tagsDaoProvider).getTagsForTask(task.id),
        builder: (context, snapshot) {
          final tags = snapshot.data ?? [];
          if (tags.isEmpty) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: tags.map((tag) => TagBadge(tag: tag)).toList(),
            ),
          );
        },
      ),
      prefix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(FLucideIcons.gripVertical, size: 20),
            ),
          ),
          FCheckbox(
            value: isDone,
            onChange: (value) => _toggleTaskDone(ref, task, log, value),
          ),
        ],
      ),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSkipped)
            FBadge(
              variant: FBadgeVariant.secondary,
              child: const Text('Skipped'),
            )
          else if (!isDone)
            FButton.icon(
              variant: FButtonVariant.ghost,
              onPress: () => _skipTask(ref, task, log),
              child: const Icon(FLucideIcons.circleSlash),
            ),
          const SizedBox(width: 4),
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: () => _editTask(context, ref, task),
            child: const Icon(FLucideIcons.pencil),
          ),
          const SizedBox(width: 4),
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UnifiedTextEntryPage.taskNotes(task: task, taskLog: log),
              ),
            ),
            child: Icon(
              FLucideIcons.notebookPen,
              color: log?.notes != null && log!.notes!.isNotEmpty ? FTheme.of(context).colors.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  void _editTask(BuildContext context, WidgetRef ref, Task task) async {
    final remindersDao = ref.read(remindersDaoProvider);
    final tagsDao = ref.read(tagsDaoProvider);

    final reminders = await remindersDao.getForTask(task.id);
    final tags = await tagsDao.getTagsForTask(task.id);

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddEntryPage(
            type: EntryType.task,
            task: task,
            initialReminders: reminders,
            initialTags: tags,
          ),
        ),
      );
    }
  }

  void _toggleTaskDone(WidgetRef ref, Task task, TaskLog? log, bool value) async {
    final tasksDao = ref.read(tasksDaoProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (value) {
      await tasksDao.logOccurrence(TaskLogsCompanion(
        id: drift.Value(log?.id ?? const Uuid().v4()),
        taskId: drift.Value(task.id),
        status: const drift.Value(TaskLogStatus.done),
        triggeredAt: drift.Value(log?.triggeredAt ?? today),
        createdAt: drift.Value(log?.createdAt ?? DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ));
    } else {
      if (log != null) {
        await tasksDao.deleteLog(log.id);
      }
    }
  }

  void _skipTask(WidgetRef ref, Task task, TaskLog? log) async {
    final tasksDao = ref.read(tasksDaoProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await tasksDao.logOccurrence(TaskLogsCompanion(
      id: drift.Value(log?.id ?? const Uuid().v4()),
      taskId: drift.Value(task.id),
      status: const drift.Value(TaskLogStatus.skipped),
      triggeredAt: drift.Value(log?.triggeredAt ?? today),
      createdAt: drift.Value(log?.createdAt ?? DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));
  }
}
