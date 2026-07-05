import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/presentation/pages/add_task.dart';

class TaskDetailsPage extends ConsumerWidget {
  final Task task;
  final List<Tag> tags;

  const TaskDetailsPage({
    super.key,
    required this.task,
    required this.tags,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsStream = ref.watch(pomodoroSessionsDaoProvider).watchSessionsForTask(task.id);
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
                    builder: (context) => AddTaskPage(
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
            Text(task.notes!),
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
          if (task.recurrenceRule != null) ...[
             Text(
              'Recurrence',
              style: FTheme.of(context).typography.body.sm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: FTheme.of(context).colors.mutedForeground,
                  ),
            ),
            const SizedBox(height: 8),
            Text(task.recurrenceRule!.toString()),
            const SizedBox(height: 24),
          ],
          
          const SizedBox(height: 40),
          Text(
            'Session History',
            style: FTheme.of(context).typography.body.lg.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<PomodoroSession>>(
            stream: sessionsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final sessions = snapshot.data ?? [];
              if (sessions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No sessions recorded yet.')),
                );
              }

              return Column(
                children: sessions.map((session) {
                  return FTile(
                    title: Text('${session.durationSeconds ~/ 60} minutes'),
                    subtitle: Text(
                      '${session.startedAt.year}-${session.startedAt.month.toString().padLeft(2, '0')}-${session.startedAt.day.toString().padLeft(2, '0')} '
                      '${session.startedAt.hour.toString().padLeft(2, '0')}:${session.startedAt.minute.toString().padLeft(2, '0')}',
                    ),
                    suffix: FBadge(
                      variant: session.status == PomodoroStatus.completed ? FBadgeVariant.secondary : FBadgeVariant.outline,
                      child: Text(session.status.name.toUpperCase()),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
