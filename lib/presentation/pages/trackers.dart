import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/data/daos/trackers_dao.dart';
import 'add_entry_page.dart';
import 'tracker_details.dart';
import 'tag_dialogs.dart';

class TrackersPage extends ConsumerStatefulWidget {
  final VoidCallback? onMenuPressed;

  const TrackersPage({super.key, this.onMenuPressed});

  @override
  ConsumerState<TrackersPage> createState() => _TrackersPageState();
}

class _TrackersPageState extends ConsumerState<TrackersPage> {
  final Set<String> _selectedTagIds = {};
  bool _isReorderMode = false;

  void _showFilterDialog() async {
    final result = await showTagFilterDialog(
      context: context,
      title: 'Filter by Tags',
      initialSelectedTagIds: _selectedTagIds,
      onReset: () {
        setState(() {
          _selectedTagIds.clear();
        });
      },
    );

    if (result != null) {
      setState(() {
        _selectedTagIds.clear();
        _selectedTagIds.addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackersAsync = ref.watch(trackersProvider);
    final isFilterActive = _selectedTagIds.isNotEmpty;

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Trackers'),
        prefixes: [
          if (widget.onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: widget.onMenuPressed!,
            ),
        ],
        suffixes: [
          if (_selectedTagIds.isEmpty)
            FHeaderAction(
              icon: Icon(
                FLucideIcons.listOrdered,
                color: _isReorderMode ? FTheme.of(context).colors.primary : null,
              ),
              onPress: () => setState(() => _isReorderMode = !_isReorderMode),
            ),
          FHeaderAction(
            icon: Icon(
              FLucideIcons.filter,
              color: isFilterActive ? FTheme.of(context).colors.primary : null,
            ),
            onPress: _showFilterDialog,
          ),
        ],
      ),
      child: Stack(
        children: [
          trackersAsync.when(
            data: (trackers) {
              var filteredTrackers = trackers;
              if (_selectedTagIds.isNotEmpty) {
                filteredTrackers = trackers.where((t) => t.tags.any((tag) => _selectedTagIds.contains(tag.id))).toList();
              }

              if (filteredTrackers.isEmpty) {
                return Center(
                  child: Text(_selectedTagIds.isNotEmpty ? 'No trackers match your filters.' : 'No trackers yet. Add one!'),
                );
              }

              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.all(16),
                itemCount: filteredTrackers.length,
                onReorderItem: (oldIndex, newIndex) {
                  if (_selectedTagIds.isNotEmpty) return; // Disable reorder when filtered
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = filteredTrackers.removeAt(oldIndex);
                  filteredTrackers.insert(newIndex, item);
                  ref.read(trackersDaoProvider).updatePositions(
                        filteredTrackers.map((t) => t.tracker.id).toList(),
                      );
                },
                itemBuilder: (context, index) {
                  final tracker = filteredTrackers[index];
                  return Padding(
                    key: ValueKey(tracker.tracker.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TrackerTile(
                      item: tracker,
                      index: index,
                      isReorderable: _selectedTagIds.isEmpty && _isReorderMode,
                    ),
                  );
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
                MaterialPageRoute(builder: (context) => const AddEntryPage(type: EntryType.tracker)),
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
  final int index;
  final bool isReorderable;

  const TrackerTile({
    super.key,
    required this.item,
    required this.index,
    this.isReorderable = true,
  });

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
      title: Row(
        children: [
          Expanded(child: Text(widget.item.tracker.title)),
          if (widget.item.tracker.unit != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '(${widget.item.tracker.unit})',
                style: FTheme.of(context).typography.body.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
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
            ],
          ),
          if (widget.item.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: widget.item.tags.map((tag) => TagBadge(tag: tag)).toList(),
            ),
          ],
        ],
      ),
      prefix: widget.isReorderable
          ? ReorderableDragStartListener(
              index: widget.index,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(FLucideIcons.gripVertical, size: 20),
              ),
            )
          : null,
      onPress: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TrackerDetailsPage(tracker: widget.item.tracker),
        ),
      ),
    );
  }

}
