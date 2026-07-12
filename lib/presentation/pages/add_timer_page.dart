import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/utils/notification_service.dart';
import 'package:flutter_picker_plus/picker.dart';

class AddTimerPage extends ConsumerStatefulWidget {
  const AddTimerPage({super.key});

  @override
  ConsumerState<AddTimerPage> createState() => _AddTimerPageState();
}

class _AddTimerPageState extends ConsumerState<AddTimerPage> {
  final _labelController = TextEditingController();
  int _durationSeconds = 0;
  final _selectedTagIds = <String>{};

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();

    if (_durationSeconds <= 0) return;

    final id = const Uuid().v4();
    final startedAt = DateTime.now();

    final timersDao = ref.read(timersDaoProvider);
    final tagsDao = ref.read(tagsDaoProvider);

    await timersDao.upsert(TimersCompanion.insert(
      id: id,
      label: drift.Value(label.isEmpty ? null : label),
      durationSeconds: _durationSeconds,
      startedAt: startedAt,
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));

    for (final tagId in _selectedTagIds) {
      await tagsDao.attachToTimer(id, tagId);
    }

    // Schedule notification
    final scheduledTime = startedAt.add(Duration(seconds: _durationSeconds));
    await NotificationService().scheduleTimerNotification(
      id: id,
      title: 'Timer Finished',
      body: label.isEmpty ? 'Your timer is done!' : 'Timer "$label" is done!',
      scheduledTime: scheduledTime,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showPicker(BuildContext context) {
    final hours = _durationSeconds ~/ 3600;
    final minutes = (_durationSeconds % 3600) ~/ 60;
    final seconds = _durationSeconds % 60;

    Picker(
      adapter: NumberPickerAdapter(data: [
        NumberPickerColumn(begin: 0, end: 23, suffix: const Text(' h'), initValue: hours),
        NumberPickerColumn(begin: 0, end: 59, suffix: const Text(' m'), initValue: minutes),
        NumberPickerColumn(begin: 0, end: 59, suffix: const Text(' s'), initValue: seconds),
      ]),
      delimiter: [
        PickerDelimiter(
          child: Container(
            width: 30.0,
            alignment: Alignment.center,
            child: const Icon(Icons.more_vert),
          ),
        )
      ],
      hideHeader: true,
      title: const Text("Select Duration"),
      onConfirm: (Picker picker, List<int> value) {
        final selectedValues = picker.getSelectedValues();
        setState(() {
          _durationSeconds = (selectedValues[0] as int) * 3600 +
              (selectedValues[1] as int) * 60 +
              (selectedValues[2] as int);
        });
      },
    ).showDialog(context);
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Add Timer'),
        prefixes: [
          FHeaderAction.x(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duration',
              style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showPicker(context),
              child: AbsorbPointer(
                child: FTextField(
                  readOnly: true,
                  hint: 'Select HH:MM:SS',
                  control: FTextFieldControl.managed(
                    controller: TextEditingController(
                      text: _durationSeconds > 0 ? _formatDuration(_durationSeconds) : '',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FTextField(
              label: const Text('Label (Optional)'),
              hint: 'What is this timer for?',
              control: FTextFieldControl.managed(controller: _labelController),
            ),
            const SizedBox(height: 24),
            _buildTagsSection(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: _save,
                child: const Text('Start Timer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tags (Optional)',
              style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
            ),
            FButton.icon(
              variant: FButtonVariant.ghost,
              size: FButtonSizeVariant.sm,
              onPress: () async {
                final tagId = await showAddTagDialog(context, ref);
                if (tagId != null) {
                  setState(() {
                    _selectedTagIds.add(tagId);
                  });
                }
              },
              child: const Icon(FLucideIcons.plus),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Tag>>(
          stream: ref.watch(tagsDaoProvider).watchAll(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Text(
                'No tags available',
                style: FTheme.of(context).typography.body.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
              );
            }

            final tags = snapshot.data!;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                final isSelected = _selectedTagIds.contains(tag.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTagIds.remove(tag.id);
                      } else {
                        _selectedTagIds.add(tag.id);
                      }
                    });
                  },
                  child: TagBadge(
                    tag: tag,
                    variant: isSelected ? FBadgeVariant.primary : FBadgeVariant.outline,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
