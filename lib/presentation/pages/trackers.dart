import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'add_tracker.dart';
import 'tracker_details.dart';

class TrackersPage extends ConsumerWidget {
  final VoidCallback? onMenuPressed;

  const TrackersPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackersAsync = ref.watch(trackersDaoProvider).watchAll();

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
          StreamBuilder<List<Tracker>>(
            stream: trackersAsync,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final trackers = snapshot.data ?? [];

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
                  return TrackerTile(tracker: tracker);
                },
              );
            },
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
  final Tracker tracker;

  const TrackerTile({super.key, required this.tracker});

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
      trackerId: drift.Value(widget.tracker.id),
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
        title: Text('Logged ${widget.tracker.title}'),
        description: Text('Value: $value ${widget.tracker.unit ?? ''}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInteger = widget.tracker.valueType == TrackerValueType.integer;
    
    return FTile(
      title: Text(widget.tracker.title),
      subtitle: widget.tracker.unit != null ? Text('Unit: ${widget.tracker.unit}') : null,
      onPress: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TrackerDetailsPage(tracker: widget.tracker),
        ),
      ),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: FTextField(
              hint: isInteger ? '0' : '0.0',
              keyboardType: isInteger 
                ? TextInputType.number 
                : const TextInputType.numberWithOptions(decimal: true),
              control: FTextFieldControl.managed(controller: _valueController),
            ),
          ),
          const SizedBox(width: 8),
          FButton.icon(
            variant: FButtonVariant.outline,
            onPress: _logValue,
            child: const Icon(FLucideIcons.check),
          ),
        ],
      ),
    );
  }
}
