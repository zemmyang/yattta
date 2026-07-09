import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/pages/add_entry_page.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/data/daos/tasks_dao.dart';
import 'package:yattta/presentation/pages/unified_text_entry.dart';
import 'package:yattta/presentation/pages/task_details.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';

class TasksPage extends ConsumerStatefulWidget {
  final VoidCallback? onMenuPressed;

  const TasksPage({super.key, this.onMenuPressed});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final Set<String> _selectedTagIds = {};

  void _showFilterDialog() async {
    final result = await showTagFilterDialog(
      context: context,
      title: 'Filter by Tags',
      initialSelectedTagIds: _selectedTagIds,
      onReset: () {
        setState(() {
          _selectedTagIds.clear();
        });
      },
    );

    if (result != null) {
      setState(() {
        _selectedTagIds.clear();
        _selectedTagIds.addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksWithTagsProvider);
    final logsAsync = ref.watch(todayLogsProvider);
    final remindersAsync = ref.watch(activeRemindersProvider);
    final isFilterActive = _selectedTagIds.isNotEmpty;

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Tasks'),
        prefixes: [
          if (widget.onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: widget.onMenuPressed!,
            ),
        ],
        suffixes: [
          FHeaderAction(
            icon: Icon(
              FLucideIcons.filter,
              color: isFilterActive ? FTheme.of(context).colors.primary : null,
            ),
            onPress: _showFilterDialog,
          ),
        ],
      ),
      child: Stack(
        children: [
          tasksAsync.when(
            data: (tasks) {
              var filteredTasks = tasks.where((t) => t.task.isActive && t.task.deletedAt == null).toList();

              if (_selectedTagIds.isNotEmpty) {
                filteredTasks = filteredTasks.where((t) => t.tags.any((tag) => _selectedTagIds.contains(tag.id))).toList();
              }

              return logsAsync.when(
                data: (logs) => remindersAsync.when(
                  data: (reminders) => _buildTaskList(context, ref, filteredTasks, logs, reminders),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error loading reminders: $err')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading logs: $err')),
              );
            },
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

  Widget _buildTaskList(
      BuildContext context, WidgetRef ref, List<TaskWithTags> allTasks, List<TaskLog> logs, List<Reminder> allReminders) {
    if (allTasks.isEmpty) {
      return Center(
        child: Text(_selectedTagIds.isNotEmpty ? 'No tasks match your filters.' : 'No active tasks. Add one!'),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todayTasks = <TaskWithTags>[];
    final noRemindersTasks = <TaskWithTags>[];
    final futureTasks = <TaskWithTags>[];

    for (final taskWithTags in allTasks) {
      final task = taskWithTags.task;
      final taskReminders = allReminders.where((r) => r.taskId == task.id).toList();
      if (taskReminders.isEmpty) {
        noRemindersTasks.add(taskWithTags);
      } else if (taskReminders.any((r) => r.remindAt.isBefore(tomorrow))) {
        todayTasks.add(taskWithTags);
      } else {
        futureTasks.add(taskWithTags);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (todayTasks.isNotEmpty) _buildTaskGroup(context, ref, 'Today', todayTasks, logs),
          if (noRemindersTasks.isNotEmpty) _buildTaskGroup(context, ref, 'No reminders set', noRemindersTasks, logs),
          if (futureTasks.isNotEmpty) _buildTaskGroup(context, ref, 'Future', futureTasks, logs),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildTaskGroup(BuildContext context, WidgetRef ref, String title, List<TaskWithTags> tasks, List<TaskLog> logs) {
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
              if (_selectedTagIds.isNotEmpty) return; // Disable reorder when filtered
              final item = tasks.removeAt(oldIndex);
              tasks.insert(newIndex, item);
              ref.read(tasksDaoProvider).updatePositions(
                    tasks.map((t) => t.task.id).toList(),
                  );
            },
            itemBuilder: (context, index) {
              final taskWithTags = tasks[index];
              final log = logs.where((l) => l.taskId == taskWithTags.task.id).firstOrNull;
              return _buildTaskTile(context, ref, taskWithTags, log, index);
            },
          ),
        ],
      ),
    );
  }

  FTile _buildTaskTile(BuildContext context, WidgetRef ref, TaskWithTags taskWithTags, TaskLog? log, int index) {
    final task = taskWithTags.task;
    final tags = taskWithTags.tags;
    final isDone = log?.status == TaskLogStatus.done;
    final isSkipped = log?.status == TaskLogStatus.skipped;

    return FTile(
      key: ValueKey(task.id),
      onPress: () async {
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
      subtitle: tags.isEmpty
          ? const SizedBox()
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: tags.map((tag) => TagBadge(tag: tag)).toList(),
              ),
            ),
      prefix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedTagIds.isEmpty)
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
            onPress: () => _editTask(context, ref, task, tags),
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

  void _editTask(BuildContext context, WidgetRef ref, Task task, List<Tag> tags) async {
    final remindersDao = ref.read(remindersDaoProvider);
    final reminders = await remindersDao.getForTask(task.id);

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
