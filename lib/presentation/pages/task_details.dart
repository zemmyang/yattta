import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/presentation/pages/add_entry_page.dart';
import 'package:yattta/presentation/widgets/note_renderer.dart';

import 'package:intl/intl.dart';

class TaskDetailsPage extends ConsumerStatefulWidget {
  final Task task;
  final List<Tag> tags;

  const TaskDetailsPage({
    super.key,
    required this.task,
    required this.tags,
  });

  @override
  ConsumerState<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends ConsumerState<TaskDetailsPage> {
  final Set<int> _expandedIndices = {0}; // Expand the first month by default
  final Set<TaskLogStatus> _selectedStatuses = {
    TaskLogStatus.done,
    TaskLogStatus.notDone,
    TaskLogStatus.skipped
  };

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final tags = widget.tags;
    final ref = this.ref;
    // Task logs for history (optional, can add if needed)

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Task Details'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.pencil),
            onPress: () async {
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
            },
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            task.title,
            style: FTheme.of(context).typography.body.lg.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (task.notes != null && task.notes!.isNotEmpty) ...[
            Text(
              'Notes',
              style: FTheme.of(context).typography.body.sm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: FTheme.of(context).colors.mutedForeground,
                  ),
            ),
            const SizedBox(height: 8),
            NoteRenderer(note: task.notes),
            const SizedBox(height: 24),
          ],
          if (tags.isNotEmpty) ...[
            Text(
              'Tags',
              style: FTheme.of(context).typography.body.sm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: FTheme.of(context).colors.mutedForeground,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => TagBadge(tag: tag)).toList(),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Recurrence',
            style: FTheme.of(context).typography.body.sm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: FTheme.of(context).colors.mutedForeground,
                ),
          ),
          const SizedBox(height: 8),
          Text(task.recurrenceRule.toString()),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task History',
                style: FTheme.of(context).typography.body.lg.copyWith(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 4,
                children: TaskLogStatus.values.map((status) {
                  final isSelected = _selectedStatuses.contains(status);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          if (_selectedStatuses.length > 1) {
                            _selectedStatuses.remove(status);
                          }
                        } else {
                          _selectedStatuses.add(status);
                        }
                      });
                    },
                    child: FBadge(
                      variant: isSelected ? FBadgeVariant.secondary : FBadgeVariant.outline,
                      child: Text(status.name.toUpperCase()),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ref.watch(taskLogsForTaskProvider(task.id)).when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No history yet.')),
                    );
                  }

                  // Group logs by month
                  final groupedLogs = <String, List<TaskLog>>{};
                  final monthKeys = <String>[];
                  for (final log in logs) {
                    if (!_selectedStatuses.contains(log.status)) continue;

                    final key = DateFormat('MMMM yyyy').format(log.triggeredAt);
                    if (!groupedLogs.containsKey(key)) {
                      groupedLogs[key] = [];
                      monthKeys.add(key);
                    }
                    groupedLogs[key]!.add(log);
                  }

                  return FAccordion(
                    control: FAccordionControl.lifted(
                      expanded: (index) => _expandedIndices.contains(index),
                      onChange: (index, expanded) => setState(() {
                        if (expanded) {
                          _expandedIndices.add(index);
                        } else {
                          _expandedIndices.remove(index);
                        }
                      }),
                    ),
                    children: monthKeys.asMap().entries.map((entry) {
                      final monthKey = entry.value;
                      final monthLogs = groupedLogs[monthKey]!;

                      return FAccordionItem(
                        title: Text(monthKey),
                        child: Column(
                          children: monthLogs.map((log) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: FTile(
                                title: Text(
                                  DateFormat('yyyy-MM-dd').format(log.triggeredAt),
                                ),
                                subtitle: log.notes != null && log.notes!.isNotEmpty
                                    ? Text(
                                        log.notes!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                suffix: FBadge(
                                  variant: log.status == TaskLogStatus.done ? FBadgeVariant.secondary : FBadgeVariant.outline,
                                  child: Text(log.status.name.toUpperCase()),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
        ],
      ),
    );
  }
}
