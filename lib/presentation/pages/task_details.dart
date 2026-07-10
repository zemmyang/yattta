import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/presentation/pages/add_entry_page.dart';
import 'package:yattta/presentation/widgets/note_renderer.dart';
import 'package:yattta/presentation/widgets/log_accordion.dart';
import 'package:heatmap_calendar_plus/heatmap_calendar_plus.dart';
import 'package:yattta/utils/settings_controller.dart';

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
  final Set<TaskLogStatus> _selectedStatuses = {
    TaskLogStatus.done,
  };

  final HeatMapCalendarController _calendarController = HeatMapCalendarController();

  Widget _buildCalendar(List<TaskLog> logs, Task task) {
    final Map<DateTime, int> datasets = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Map logs for easy lookup
    final Map<DateTime, TaskLogStatus> logMap = {
      for (final log in logs)
        DateTime(log.triggeredAt.year, log.triggeredAt.month, log.triggeredAt.day): log.status
    };

    // Go back as far as the task was created
    final taskCreatedDate = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);

    int i = 0;
    while (true) {
      final date = today.subtract(Duration(days: i));
      if (date.isBefore(taskCreatedDate)) break;

      final status = logMap[date];

      if (status == TaskLogStatus.done) {
        datasets[date] = 1;
      } else if (status == TaskLogStatus.skipped) {
        datasets[date] = 2;
      } else if (task.recurrenceRule.isDueOn(date)) {
        // If due but no log, it's "Not Done"
        // Only if it's in the past (before today)
        if (date.isBefore(today)) {
          datasets[date] = 3;
        }
      }
      i++;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FTheme.of(context).colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FTheme.of(context).colors.border),
      ),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: HeatMapCalendar(
            controller: _calendarController,
            headerBuilder: (context, currentDate) {
              final date = currentDate ?? DateTime.now();
              final startOfCreation = DateTime(task.createdAt.year, task.createdAt.month, 1);
              final startOfToday = DateTime(now.year, now.month, 1);

              final canGoBack = date.isAfter(startOfCreation);
              final canGoForward = date.isBefore(startOfToday);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    onPressed: canGoBack ? () => _calendarController.previousMonth() : null,
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(date),
                    style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                    onPressed: canGoForward ? () => _calendarController.nextMonth() : null,
                  ),
                ],
              );
            },
            datasets: datasets,
            colorMode: ColorMode.color,
            defaultColor: FTheme.of(context).colors.muted,
            size: 25,
            weekStartsWith: settingsController.startOfWeek == DateTime.sunday ? 7 : settingsController.startOfWeek,
            dayTextStyle: TextStyle(
              color: FTheme.of(context).colors.foreground,
              fontSize: 10,
            ),
            monthTextStyle: TextStyle(
              color: FTheme.of(context).colors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            weekTextStyle: TextStyle(
              color: FTheme.of(context).colors.foreground,
              fontSize: 10,
            ),
            colorsets: const {
              1: Colors.green,
              2: Colors.orange,
              3: Colors.red,
            },
            onClick: (date) {
              // Show status for that day
              final val = datasets[date];
              String statusText = 'Not Due';
              if (val == 1) statusText = 'Done';
              if (val == 2) statusText = 'Skipped';
              if (val == 3) statusText = 'Not Done';

              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              showFToast(
                context: context,
                title: Text(statusText),
                description: Text(dateStr),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final tags = widget.tags;
    final ref = this.ref;

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
          Text(
            'Created on ${DateFormat('yyyy-MM-dd').format(task.createdAt)}',
            style: FTheme.of(context).typography.body.xs.copyWith(
                  color: FTheme.of(context).colors.mutedForeground,
                ),
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
          const SizedBox(height: 24),
          ref.watch(taskLogsForTaskProvider(task.id)).when(
                data: (logs) {
                  final isPowerUser = settingsController.userMode == UserMode.powerUser;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPowerUser) ...[
                        Center(
                          child: Text(
                            'Habit Calendar',
                            style: FTheme.of(context).typography.body.lg.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCalendar(logs, task),
                        const SizedBox(height: 32),
                      ],
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Task History',
                              style: FTheme.of(context).typography.body.lg.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
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
                      ),
                      const SizedBox(height: 8),
                      () {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final historyEntries = <_HistoryEntry>[];

                        // 2. We want to show all real logs AND inferred missed days
                        // For missed days, we go back to when the task was created to match the calendar
                        final Set<DateTime> processedDates = {};

                        // Add all real logs
                        for (final log in logs) {
                          final date = DateTime(log.triggeredAt.year, log.triggeredAt.month, log.triggeredAt.day);
                          historyEntries.add(_HistoryEntry(
                            triggeredAt: log.triggeredAt,
                            status: log.status,
                            notes: log.notes,
                          ));
                          processedDates.add(date);
                        }

                        // Synthesize missed days back to the task creation date
                        final taskCreatedDate = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
                        int i = 0;
                        while (true) {
                          final date = today.subtract(Duration(days: i));
                          if (date.isBefore(taskCreatedDate)) break;
                          if (processedDates.contains(date)) {
                            i++;
                            continue;
                          }

                          if (task.recurrenceRule.isDueOn(date) && date.isBefore(today)) {
                            historyEntries.add(_HistoryEntry(
                              triggeredAt: date,
                              status: TaskLogStatus.notDone,
                            ));
                          }
                          i++;
                        }

                        // Sort all by triggeredAt DESC
                        historyEntries.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));

                        // Filter by selected statuses
                        final filteredEntries = historyEntries.where((e) => _selectedStatuses.contains(e.status)).toList();

                        return LogAccordion<_HistoryEntry>(
                          items: filteredEntries,
                          getTimestamp: (e) => e.triggeredAt,
                          emptyMessage: 'No history matching filters.',
                          itemBuilder: (context, historyEntry) => FTile(
                            title: Text(
                              DateFormat('yyyy-MM-dd').format(historyEntry.triggeredAt),
                            ),
                            subtitle: historyEntry.notes != null && historyEntry.notes!.isNotEmpty
                                ? Text(
                                    historyEntry.notes!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            suffix: FBadge(
                              variant: historyEntry.status == TaskLogStatus.done ? FBadgeVariant.secondary : FBadgeVariant.outline,
                              child: Text(historyEntry.status.name.toUpperCase()),
                            ),
                          ),
                        );
                      }(),
                    ],
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

class _HistoryEntry {
  final DateTime triggeredAt;
  final TaskLogStatus status;
  final String? notes;

  _HistoryEntry({
    required this.triggeredAt,
    required this.status,
    this.notes,
  });
}
