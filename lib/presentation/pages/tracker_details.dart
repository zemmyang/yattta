import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:drift/drift.dart' as drift;

class TrackerDetailsPage extends ConsumerWidget {
  final Tracker tracker;

  const TrackerDetailsPage({super.key, required this.tracker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsStream = ref.watch(trackersDaoProvider).watchLogsForTracker(tracker.id);

    return FScaffold(
      header: FHeader.nested(
        title: Text(tracker.title),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
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

          // Determine chart color based on trend and direction
          Color chartColor = FTheme.of(context).colors.primary;
          if (logs.length >= 2) {
            final firstValue = logs.first.value;
            final lastValue = logs.last.value;
            final isIncreasing = lastValue > firstValue;
            final isDecreasing = lastValue < firstValue;

            if (tracker.direction == TrackerDirection.increasing) {
              chartColor = isIncreasing ? Colors.green : Colors.red;
            } else if (tracker.direction == TrackerDirection.decreasing) {
              chartColor = isDecreasing ? Colors.green : Colors.red;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              if (logs.isEmpty) return const Text('');
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
                          spots: logs.map((log) {
                            return FlSpot(
                              log.loggedAt.millisecondsSinceEpoch.toDouble(),
                              log.value,
                            );
                          }).toList(),
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Logs',
                style: FTheme.of(context).typography.body.lg.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...logs.reversed.map((log) {
                final displayValue = tracker.valueType == TrackerValueType.integer 
                  ? log.value.toInt().toString() 
                  : log.value.toStringAsFixed(1);

                return FTile(
                  title: Text('$displayValue ${tracker.unit ?? ''}'),
                  subtitle: Text(
                    '${log.loggedAt.year}-${log.loggedAt.month.toString().padLeft(2, '0')}-${log.loggedAt.day.toString().padLeft(2, '0')} '
                    '${log.loggedAt.hour.toString().padLeft(2, '0')}:${log.loggedAt.minute.toString().padLeft(2, '0')}',
                  ),
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FButton.icon(
                        variant: FButtonVariant.ghost,
                        onPress: () => _editLog(context, ref, log),
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
              }),
            ],
          );
        },
      ),
    );
  }

  void _editLog(BuildContext context, WidgetRef ref, TrackerLog log) async {
    final initialValue = tracker.valueType == TrackerValueType.integer 
      ? log.value.toInt().toString() 
      : log.value.toString();
      
    final valueController = TextEditingController(text: initialValue);
    DateTime selectedDate = log.loggedAt;

    await showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        animation: animation,
        title: const Text('Edit Log'),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FTextField(
              label: const Text('Value'),
              control: FTextFieldControl.managed(controller: valueController),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            FButton(
              variant: FButtonVariant.outline,
              onPress: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null && context.mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(selectedDate),
                  );
                  if (time != null) {
                    selectedDate = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  }
                }
              },
              child: const Text('Change Date/Time'),
            ),
          ],
        ),
        actions: [
          FButton(
            onPress: () async {
              final value = double.tryParse(valueController.text);
              if (value != null) {
                await ref.read(trackersDaoProvider).updateLog(
                      TrackerLogsCompanion(
                        id: drift.Value(log.id),
                        value: drift.Value(value),
                        loggedAt: drift.Value(selectedDate),
                      ),
                    );
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
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
