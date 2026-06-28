import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/data/daos/trackers_dao.dart';
import 'add_tracker.dart';
import 'tracker_details.dart';
import 'tag_dialogs.dart';

class TrackersPage extends ConsumerWidget {
  final VoidCallback? onMenuPressed;

  const TrackersPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackersAsync = ref.watch(trackersProvider);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Trackers'),
        prefixes: [
          if (onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: onMenuPressed!,
            ),
        ],
      ),
      child: Stack(
        children: [
          trackersAsync.when(
            data: (trackers) {
              if (trackers.isEmpty) {
                return const Center(
                  child: Text('No trackers yet. Add one!'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: trackers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tracker = trackers[index];
                  return TrackerTile(item: tracker);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FButton.icon(
              onPress: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddTrackerPage()),
              ),
              child: const Icon(FLucideIcons.plus),
            ),
          ),
        ],
      ),
    );
  }
}

class TrackerTile extends ConsumerStatefulWidget {
  final TrackerWithTags item;

  const TrackerTile({super.key, required this.item});

  @override
  ConsumerState<TrackerTile> createState() => _TrackerTileState();
}

class _TrackerTileState extends ConsumerState<TrackerTile> {
  final _valueController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _logValue() async {
    final text = _valueController.text.trim();
    if (text.isEmpty) return;

    final value = double.tryParse(text);
    if (value == null) return;

    final trackersDao = ref.read(trackersDaoProvider);
    await trackersDao.addLog(TrackerLogsCompanion(
      id: drift.Value(const Uuid().v4()),
      trackerId: drift.Value(widget.item.tracker.id),
      value: drift.Value(value),
      loggedAt: drift.Value(DateTime.now()),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));

    _valueController.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      showFToast(
        context: context,
        title: Text('Logged ${widget.item.tracker.title}'),
        description: Text('Value: $value ${widget.item.tracker.unit ?? ''}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInteger = widget.item.tracker.valueType == TrackerValueType.integer;

    return FTile(
      title: Text(widget.item.tracker.title),
      subtitle: widget.item.tags.isEmpty && widget.item.tracker.unit == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.item.tracker.unit != null) Text('Unit: ${widget.item.tracker.unit}'),
                if (widget.item.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: widget.item.tags
                        .map((tag) => TagBadge(tag: tag))
                        .toList(),
                  ),
                ],
              ],
            ),
      onPress: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TrackerDetailsPage(tracker: widget.item.tracker),
        ),
      ),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: FTextField(
              hint: isInteger ? '0' : '0.0',
              keyboardType: isInteger ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
              control: FTextFieldControl.managed(controller: _valueController),
            ),
          ),
          const SizedBox(width: 8),
          FButton.icon(
            variant: FButtonVariant.outline,
            onPress: _logValue,
            child: const Icon(FLucideIcons.check),
          ),
          const SizedBox(width: 8),
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: () => _deleteTracker(context, ref, widget.item.tracker),
            child: const Icon(FLucideIcons.trash),
          ),
        ],
      ),
    );
  }

  void _deleteTracker(BuildContext context, WidgetRef ref, Tracker tracker) async {
    final confirm = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('Delete Tracker'),
        body: const Text('Are you sure you want to move this tracker to the recycle bin?'),
        actions: [
          FButton(
            onPress: () => Navigator.of(context).pop(false),
            variant: FButtonVariant.ghost,
            child: const Text('Cancel'),
          ),
          FButton(
            onPress: () => Navigator.of(context).pop(true),
            variant: FButtonVariant.destructive,
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(trackersDaoProvider).softDelete(tracker.id);
    }
  }
}
