import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/presentation/pages/add_timer_page.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/utils/notification_service.dart';
import 'package:yattta/data/daos/timers_dao.dart';

class TimersPage extends ConsumerWidget {
  final VoidCallback onMenuPressed;

  const TimersPage({super.key, required this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timersAsync = ref.watch(timersProvider);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Timers'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.menu),
            onPress: onMenuPressed,
          ),
        ],
      ),
      child: Stack(
        children: [
          timersAsync.when(
            data: (timersWithTags) {
              if (timersWithTags.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FLucideIcons.timer,
                        size: 48,
                        color: FTheme.of(context).colors.mutedForeground,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No timers yet',
                        style: FTheme.of(context).typography.body.md.copyWith(
                              color: FTheme.of(context).colors.mutedForeground,
                            ),
                      ),
                    ],
                  ),
                );
              }

              final activeTimers = timersWithTags.where((t) {
                final endTime = t.timer.startedAt.add(Duration(seconds: t.timer.durationSeconds));
                return !t.timer.isCancelled && endTime.isAfter(DateTime.now());
              }).toList();

              final pastTimers = timersWithTags.where((t) {
                final endTime = t.timer.startedAt.add(Duration(seconds: t.timer.durationSeconds));
                return t.timer.isCancelled || endTime.isBefore(DateTime.now());
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (activeTimers.isNotEmpty) ...[
                    Text(
                      'Active Timers',
                      style: FTheme.of(context).typography.body.md.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...activeTimers.map((t) => _TimerCard(timerWithTags: t, isActive: true)),
                    const SizedBox(height: 24),
                  ],
                  if (pastTimers.isNotEmpty) ...[
                    Text(
                      'Recent Timers',
                      style: FTheme.of(context).typography.body.md.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...pastTimers.map((t) => _TimerCard(timerWithTags: t, isActive: false)),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FButton.icon(
              onPress: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddTimerPage()),
              ),
              child: const Icon(FLucideIcons.plus),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends ConsumerStatefulWidget {
  final TimerWithTags timerWithTags;
  final bool isActive;

  const _TimerCard({required this.timerWithTags, required this.isActive});

  @override
  ConsumerState<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends ConsumerState<_TimerCard> {
  Timer? _ticker;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    if (widget.isActive) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _updateRemaining();
        });
        if (_remaining.inSeconds <= 0) {
          _ticker?.cancel();
        }
      });
    }
  }

  void _updateRemaining() {
    final endTime = widget.timerWithTags.timer.startedAt.add(Duration(seconds: widget.timerWithTags.timer.durationSeconds));
    _remaining = endTime.difference(DateTime.now());
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.timerWithTags.timer;
    final tags = widget.timerWithTags.tags;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.label ?? 'Timer',
                        style: FTheme.of(context).typography.body.md.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: tags.map((tag) => TagBadge(tag: tag)).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  widget.isActive ? _formatDuration(_remaining) : 'Finished',
                  style: FTheme.of(context).typography.body.lg.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.isActive ? FTheme.of(context).colors.primary : FTheme.of(context).colors.mutedForeground,
                      ),
                ),
              ],
            ),
            if (widget.isActive) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FButton(
                    variant: FButtonVariant.outline,
                    size: FButtonSizeVariant.sm,
                    onPress: () async {
                      await ref.read(timersDaoProvider).markCancelled(t.id);
                      await NotificationService().cancelTimerNotification(t.id);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Started at: ${t.startedAt.hour}:${t.startedAt.minute.toString().padLeft(2, '0')}',
                    style: FTheme.of(context).typography.body.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
                  ),
                  FButton.icon(
                    variant: FButtonVariant.ghost,
                    size: FButtonSizeVariant.sm,
                    onPress: () => ref.read(timersDaoProvider).softDelete(t.id),
                    child: const Icon(FLucideIcons.trash, size: 16),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
