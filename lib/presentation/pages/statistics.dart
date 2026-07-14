import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:heatmap_calendar_plus/heatmap_calendar_plus.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/utils/settings_controller.dart';
import 'package:yattta/main.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  final VoidCallback? onMenuPressed;

  const StatisticsPage({super.key, this.onMenuPressed});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (settingsController.horizontalStatsView) {
        ref.read(appMaxWidthProvider.notifier).state = 1200.0;
      }
    });
  }

  @override
  void dispose() {
    if (settingsController.horizontalStatsView) {
      // We use a microtask to avoid updating the provider during the dispose phase
      // and ensuring the ref is still valid for a read.
      Future.microtask(() {
        try {
          ref.read(appMaxWidthProvider.notifier).state = 450.0;
        } catch (_) {
          // Ignore if the container is already disposed
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todosProvider);
    final tasksAsync = ref.watch(tasksWithTagsProvider);
    final trackersAsync = ref.watch(trackersProvider);
    final completedSessionsAsync = ref.watch(completedSessionsProvider);

    final datasets = completedSessionsAsync.maybeWhen(
      data: (sessions) {
        final Map<DateTime, int> data = {};
        for (final session in sessions) {
          final date = DateTime(session.startedAt.year, session.startedAt.month, session.startedAt.day);
          data[date] = (data[date] ?? 0) + 1;
        }
        return data;
      },
      orElse: () => <DateTime, int>{},
    );

    final isHorizontal = settingsController.horizontalStatsView;

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Statistics'),
        prefixes: [
          if (widget.onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: widget.onMenuPressed!,
            ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummarySection(context, todosAsync, tasksAsync, trackersAsync),
          const SizedBox(height: 32),
          _buildActivitySection(context, datasets, isHorizontal: isHorizontal),
          const SizedBox(height: 32),
          Text(
            'Keep up the great work!',
            style: FTheme.of(context).typography.body.sm.copyWith(color: FTheme.of(context).colors.mutedForeground),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    AsyncValue todosAsync,
    AsyncValue tasksAsync,
    AsyncValue trackersAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: FTheme.of(context).typography.display.xl2.copyWith(fontWeight: FontWeight.bold),
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
                suffix: _buildLoadingIndicator(context),
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
                suffix: _buildLoadingIndicator(context),
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
                suffix: _buildLoadingIndicator(context),
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
      ],
    );
  }

  Widget _buildActivitySection(BuildContext context, Map<DateTime, int> datasets, {required bool isHorizontal}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: FTheme.of(context).typography.display.xl2.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: FTheme.of(context).colors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FTheme.of(context).colors.border),
          ),
          child: Align(
            alignment: Alignment.center,
            child: isHorizontal
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: HeatMap(
                      datasets: datasets,
                      colorMode: ColorMode.opacity,
                      defaultColor: FTheme.of(context).colors.muted,
                      scrollable: false,
                      size: 12,
                      startDate: DateTime.now().subtract(const Duration(days: 365)),
                      endDate: DateTime.now(),
                      showText: false,
                      weekTextStyle: const TextStyle(fontSize: 10),
                      monthTextStyle: const TextStyle(fontSize: 10),
                      colorTipHelper: [const SizedBox.shrink(), const SizedBox.shrink()],
                      colorsets: {
                        1: FTheme.of(context).colors.primary,
                      },
                      onClick: (date) => _showToast(context, datasets, date),
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: HeatMapCalendar(
                      datasets: datasets,
                      colorMode: ColorMode.opacity,
                      defaultColor: FTheme.of(context).colors.muted,
                      size: 25,
                      weekStartsWith:
                          settingsController.startOfWeek == DateTime.sunday ? 7 : settingsController.startOfWeek,
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
                      colorsets: {
                        1: FTheme.of(context).colors.primary,
                      },
                      onClick: (date) => _showToast(context, datasets, date),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: FTheme.of(context).colors.primary,
      ),
    );
  }

  void _showToast(BuildContext context, Map<DateTime, int> datasets, DateTime date) {
    final count = datasets[date] ?? 0;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    showFToast(
      context: context,
      title: Text('$count Pomodoros'),
      description: Text(dateStr),
    );
  }
}
