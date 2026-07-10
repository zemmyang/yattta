import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/utils/settings_controller.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/presentation/pages/add_entry_page.dart';
import 'package:yattta/presentation/pages/todos.dart';
import 'package:yattta/presentation/widgets/note_renderer.dart';
import 'package:yattta/presentation/widgets/log_accordion.dart';
import 'package:intl/intl.dart';

class TodoDetailsPage extends ConsumerWidget {
  final Todo todo;
  final List<Tag> tags;
  final Function(Todo) onFocus;

  const TodoDetailsPage({
    super.key,
    required this.todo,
    required this.tags,
    required this.onFocus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPowerUser = settingsController.userMode == UserMode.powerUser;
    final sessionsStream = ref.watch(pomodoroSessionsDaoProvider).watchSessionsForTodo(todo.id);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Todo Details'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.pencil),
            onPress: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddEntryPage(
                  type: EntryType.todo,
                  todo: todo,
                  initialTags: tags,
                ),
              ),
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  todo.title,
                  style: FTheme.of(context).typography.body.lg.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (todo.priority != null && todo.priority != 2)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: PriorityBadge(priority: todo.priority!),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FBadge(
            variant: todo.status == TodoStatus.done ? FBadgeVariant.secondary : FBadgeVariant.outline,
            child: Text(todo.status == TodoStatus.done ? 'DONE' : 'PENDING'),
          ),
          const SizedBox(height: 24),
          if (todo.notes != null && todo.notes!.isNotEmpty) ...[
            Text(
              'Notes',
              style: FTheme.of(context).typography.body.sm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: FTheme.of(context).colors.mutedForeground,
                  ),
            ),
            const SizedBox(height: 8),
            NoteRenderer(note: todo.notes),
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
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  context,
                  label: 'Due Date',
                  value: todo.dueAt != null
                      ? '${todo.dueAt!.year}-${todo.dueAt!.month.toString().padLeft(2, '0')}-${todo.dueAt!.day.toString().padLeft(2, '0')}'
                      : 'None',
                  icon: FLucideIcons.calendar,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _infoTile(
                  context,
                  label: 'Created At',
                  value:
                      '${todo.createdAt.year}-${todo.createdAt.month.toString().padLeft(2, '0')}-${todo.createdAt.day.toString().padLeft(2, '0')}',
                  icon: FLucideIcons.calendarClock,
                ),
              ),
            ],
          ),
          if (isPowerUser) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    context,
                    label: 'Durations',
                    value:
                        '${todo.workDuration ?? settingsController.timerDuration}w / ${todo.breakDuration ?? settingsController.breakDuration}b',
                    icon: FLucideIcons.timer,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
          const SizedBox(height: 32),
          FButton(
            onPress: () {
              onFocus(todo);
              Navigator.of(context).pop();
            },
            prefix: const Icon(FLucideIcons.target),
            child: const Text('Focus this Todo'),
          ),
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
              
              return LogAccordion<PomodoroSession>(
                items: sessions,
                getTimestamp: (s) => s.startedAt,
                emptyMessage: 'No sessions recorded yet.',
                itemBuilder: (context, session) => FTile(
                  title: Text('${session.durationSeconds ~/ 60} minutes'),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(session.startedAt),
                  ),
                  suffix: FBadge(
                    variant: session.status == PomodoroStatus.completed ? FBadgeVariant.secondary : FBadgeVariant.outline,
                    child: Text(session.status.name.toUpperCase()),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoTile(BuildContext context, {required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FTheme.of(context).colors.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: FTheme.of(context).colors.mutedForeground),
              const SizedBox(width: 4),
              Text(
                label,
                style: FTheme.of(context).typography.body.xs.copyWith(
                      color: FTheme.of(context).colors.mutedForeground,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
