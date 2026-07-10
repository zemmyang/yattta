import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/pages/add_entry_page.dart';
import 'package:yattta/presentation/widgets/note_renderer.dart';
import 'package:yattta/presentation/widgets/log_accordion.dart';
import 'package:intl/intl.dart';
import 'unified_text_entry.dart';

enum RollingAveragePeriod {
  none,
  day7,
  day30;

  String get label => switch (this) {
        RollingAveragePeriod.none => 'None',
        RollingAveragePeriod.day7 => '7d',
        RollingAveragePeriod.day30 => '30d',
      };

  Duration? get duration => switch (this) {
        RollingAveragePeriod.none => null,
        RollingAveragePeriod.day7 => const Duration(days: 7),
        RollingAveragePeriod.day30 => const Duration(days: 30),
      };
}

enum GraphViewPeriod {
  last7d,
  last30d,
  last90d,
  all;

  String get label => switch (this) {
        GraphViewPeriod.last7d => '7d',
        GraphViewPeriod.last30d => '30d',
        GraphViewPeriod.last90d => '90d',
        GraphViewPeriod.all => 'All',
      };

  Duration? get duration => switch (this) {
        GraphViewPeriod.last7d => const Duration(days: 7),
        GraphViewPeriod.last30d => const Duration(days: 30),
        GraphViewPeriod.last90d => const Duration(days: 90),
        GraphViewPeriod.all => null,
      };
}

class TrackerDetailsPage extends ConsumerStatefulWidget {
  final Tracker tracker;

  const TrackerDetailsPage({super.key, required this.tracker});

  @override
  ConsumerState<TrackerDetailsPage> createState() => _TrackerDetailsPageState();
}

class _TrackerDetailsPageState extends ConsumerState<TrackerDetailsPage> {
  RollingAveragePeriod _rollingAveragePeriod = RollingAveragePeriod.none;
  GraphViewPeriod _viewPeriod = GraphViewPeriod.all;

  List<FlSpot> _calculateRollingAverage(List<FlSpot> inputSpots, Duration window) {
    if (inputSpots.isEmpty) return [];

    final List<FlSpot> spots = [];

    // inputSpots are expected to be sorted ASC by x (timestamp)
    for (int i = 0; i < inputSpots.length; i++) {
      final currentSpot = inputSpots[i];
      final windowStart = currentSpot.x - window.inMilliseconds.toDouble();

      double sum = 0;
      int count = 0;

      for (int j = i; j >= 0; j--) {
        if (inputSpots[j].x < windowStart) break;
        sum += inputSpots[j].y;
        count++;
      }

      spots.add(FlSpot(
        currentSpot.x,
        sum / count,
      ));
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final logsStream = ref.watch(trackersDaoProvider).watchLogsForTracker(widget.tracker.id);

    return FScaffold(
      header: FHeader.nested(
        title: Text(widget.tracker.title),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.pencil),
            onPress: () async {
              final remindersDao = ref.read(remindersDaoProvider);
              final tagsDao = ref.read(tagsDaoProvider);
              final reminders = await remindersDao.getForTracker(widget.tracker.id);
              final tags = await tagsDao.getTagsForTracker(widget.tracker.id);

              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddEntryPage(
                      type: EntryType.tracker,
                      tracker: widget.tracker,
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
      child: StreamBuilder<List<TrackerLog>>(
        stream: logsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return const Center(child: Text('No data logged yet.'));
          }

          final now = DateTime.now();
          final minDate = DateTime(widget.tracker.createdAt.year, widget.tracker.createdAt.month, widget.tracker.createdAt.day);
          final maxDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

          double minXValue;
          if (_viewPeriod.duration != null) {
            minXValue = now.subtract(_viewPeriod.duration!).millisecondsSinceEpoch.toDouble();
          } else {
            // Use earliest log timestamp if 'All' is selected, fallback to minDate if no logs
            minXValue = logs.isNotEmpty 
                ? logs.first.loggedAt.millisecondsSinceEpoch.toDouble() 
                : minDate.millisecondsSinceEpoch.toDouble();
          }
          
          final minX = minXValue;
          final maxX = maxDate.millisecondsSinceEpoch.toDouble();
          final range = maxX - minX;

          // Calculate interval: at least 1 day, or more if the range is large
          double interval = 86400000.0; // 1 day in ms
          if (range > 86400000.0 * 7) {
            final double rawInterval = range / 5;
            // Round to nearest day for cleaner labels
            interval = (rawInterval / 86400000.0).ceil() * 86400000.0;
          }

          // Aggregate logs by date for the graph
          final Map<DateTime, List<double>> dailyValues = {};
          for (final log in logs) {
            final date = DateTime(log.loggedAt.year, log.loggedAt.month, log.loggedAt.day);
            dailyValues.putIfAbsent(date, () => []).add(log.value);
          }

          final List<FlSpot> dailyAverageSpots = dailyValues.entries.map((entry) {
            final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
            return FlSpot(entry.key.millisecondsSinceEpoch.toDouble(), avg);
          }).toList()..sort((a, b) => a.x.compareTo(b.x));

          // Determine chart color based on trend and direction
          Color chartColor = FTheme.of(context).colors.primary;
          if (logs.length >= 2) {
            final firstValue = logs.first.value;
            final lastValue = logs.last.value;
            final isIncreasing = lastValue > firstValue;
            final isDecreasing = lastValue < firstValue;

            if (widget.tracker.direction == TrackerDirection.increasing) {
              chartColor = isIncreasing ? Colors.green : Colors.red;
            } else if (widget.tracker.direction == TrackerDirection.decreasing) {
              chartColor = isDecreasing ? Colors.green : Colors.red;
            }
          }

          final visibleSpots = dailyAverageSpots.where((spot) => spot.x >= minX && spot.x <= maxX).toList();

          // Sort logs most recent first for the list
          final sortedLogs = List<TrackerLog>.from(logs)..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Created on ${widget.tracker.createdAt.year}-${widget.tracker.createdAt.month.toString().padLeft(2, '0')}-${widget.tracker.createdAt.day.toString().padLeft(2, '0')}',
                style: FTheme.of(context).typography.body.xs.copyWith(
                      color: FTheme.of(context).colors.mutedForeground,
                    ),
              ),
              const SizedBox(height: 16),
              if (widget.tracker.notes != null && widget.tracker.notes!.isNotEmpty) ...[
                Text(
                  'Notes',
                  style: FTheme.of(context).typography.body.sm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: FTheme.of(context).colors.mutedForeground,
                      ),
                ),
                const SizedBox(height: 8),
                NoteRenderer(note: widget.tracker.notes),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 300,
                  child: FTabs(
                    control: FTabControl.managed(
                      initial: _viewPeriod.index,
                      onChange: (index) => setState(() {
                        _viewPeriod = GraphViewPeriod.values[index];
                      }),
                    ),
                    children: GraphViewPeriod.values.map((period) {
                      return FTabEntry(
                        label: Text(period.label),
                        child: const SizedBox.shrink(),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
                  child: LineChart(
                    LineChartData(
                      clipData: const FlClipData.all(),
                      gridData: const FlGridData(show: true),
                      minX: minX,
                      maxX: maxX,
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              if (value < minX || value > maxX) return const SizedBox.shrink();
                              
                              final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                              return Text(
                                '${date.month}/${date.day}',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: visibleSpots,
                          isCurved: false,
                          color: chartColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: chartColor.withValues(alpha: 0.1),
                          ),
                        ),
                        if (_rollingAveragePeriod != RollingAveragePeriod.none)
                          LineChartBarData(
                            spots: _calculateRollingAverage(dailyAverageSpots, _rollingAveragePeriod.duration!)
                                .where((spot) => spot.x >= minX && spot.x <= maxX)
                                .toList(),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rolling Average',
                    style: FTheme.of(context).typography.body.sm.copyWith(
                      fontWeight: FontWeight.bold,
                      color: FTheme.of(context).colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 300,
                    child: FTabs(
                      control: FTabControl.managed(
                        initial: _rollingAveragePeriod.index,
                        onChange: (index) => setState(() {
                          _rollingAveragePeriod = RollingAveragePeriod.values[index];
                        }),
                      ),
                      children: RollingAveragePeriod.values.map((period) {
                        return FTabEntry(
                          label: Text(period.label),
                          child: const SizedBox.shrink(),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
                Text(
                'Logs',
                style: FTheme.of(context).typography.body.lg.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              LogAccordion<TrackerLog>(
                items: sortedLogs,
                getTimestamp: (log) => log.loggedAt,
                itemBuilder: (context, log) {
                  final displayValue = widget.tracker.valueType == TrackerValueType.integer 
                    ? log.value.toInt().toString() 
                    : log.value.toStringAsFixed(1);

                  return FTile(
                    title: Text('$displayValue ${widget.tracker.unit ?? ''}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(log.loggedAt),
                        ),
                        if (log.notes != null && log.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          NoteRenderer(
                            note: log.notes,
                            isPreview: true,
                            maxLines: 1,
                            style: FTheme.of(context).typography.body.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
                          ),
                        ],
                      ],
                    ),
                    suffix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FButton.icon(
                          variant: FButtonVariant.ghost,
                          onPress: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => UnifiedTextEntryPage.trackerLog(
                                tracker: widget.tracker,
                                trackerLog: log,
                              ),
                            ),
                          ),
                          child: const Icon(FLucideIcons.pencil),
                        ),
                        FButton.icon(
                          variant: FButtonVariant.ghost,
                          onPress: () => _deleteLog(context, ref, log),
                          child: const Icon(FLucideIcons.trash),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteLog(BuildContext context, WidgetRef ref, TrackerLog log) async {
    await showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        animation: animation,
        title: const Text('Delete Log'),
        body: const Text('Are you sure you want to delete this log entry?'),
        actions: [
          FButton(
            variant: FButtonVariant.destructive,
            onPress: () async {
              await ref.read(trackersDaoProvider).deleteLog(log.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
