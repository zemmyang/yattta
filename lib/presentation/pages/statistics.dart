import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/providers/database_providers.dart';

class StatisticsPage extends ConsumerWidget {
  final VoidCallback? onMenuPressed;

  const StatisticsPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosProvider);
    final tasksAsync = ref.watch(tasksWithTagsProvider);
    final trackersAsync = ref.watch(trackersProvider);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Statistics'),
        prefixes: [
          if (onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: onMenuPressed!,
            ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Summary',
            style: FTheme.of(context).typography.xl2.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FTileGroup(
            children: [
              todosAsync.when(
                data: (todos) => FTile(
                  title: const Text('Total Todos'),
                  suffix: Text(todos.length.toString()),
                  prefix: const Icon(FLucideIcons.listTodo),
                ),
                loading: () => FTile(
                  title: const Text('Total Todos'),
                  suffix: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FTheme.of(context).colors.primary,
                    ),
                  ),
                ),
                error: (err, stack) => FTile(
                  title: const Text('Total Todos'),
                  suffix: const Text('Error'),
                ),
              ),
              tasksAsync.when(
                data: (tasks) => FTile(
                  title: const Text('Total Tasks'),
                  suffix: Text(tasks.length.toString()),
                  prefix: const Icon(FLucideIcons.clipboardList),
                ),
                loading: () => FTile(
                  title: const Text('Total Tasks'),
                  suffix: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FTheme.of(context).colors.primary,
                    ),
                  ),
                ),
                error: (err, stack) => FTile(
                  title: const Text('Total Tasks'),
                  suffix: const Text('Error'),
                ),
              ),
              trackersAsync.when(
                data: (trackers) => FTile(
                  title: const Text('Total Trackers'),
                  suffix: Text(trackers.length.toString()),
                  prefix: const Icon(FLucideIcons.activity),
                ),
                loading: () => FTile(
                  title: const Text('Total Trackers'),
                  suffix: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FTheme.of(context).colors.primary,
                    ),
                  ),
                ),
                error: (err, stack) => FTile(
                  title: const Text('Total Trackers'),
                  suffix: const Text('Error'),
                ),
              ),
              FTile(
                title: const Text('Total Pomodoros'),
                suffix: StreamBuilder<int>(
                  stream: ref.read(pomodoroSessionsDaoProvider).watchTotalCompleted(),
                  builder: (context, snapshot) {
                    return Text(snapshot.data?.toString() ?? '0');
                  },
                ),
                prefix: const Icon(FLucideIcons.timer),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Keep up the great work!',
            style: FTheme.of(context).typography.sm.copyWith(color: FTheme.of(context).colors.mutedForeground),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
