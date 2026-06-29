import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/presentation/pages/reminder_dialogs.dart';

class AddTrackerPage extends ConsumerStatefulWidget {
  const AddTrackerPage({super.key});

  @override
  ConsumerState<AddTrackerPage> createState() => _AddTrackerPageState();
}

class _AddTrackerPageState extends ConsumerState<AddTrackerPage> {
  final _titleController = TextEditingController();
  final _unitController = TextEditingController();
  TrackerValueType _valueType = TrackerValueType.integer;
  TrackerDirection _direction = TrackerDirection.increasing;
  final _selectedTagIds = <String>{};
  final List<ReminderData> _reminders = [];

  @override
  void dispose() {
    _titleController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _addReminder() async {
    final reminderData = await showAddReminderDialog(context);
    if (reminderData != null && mounted) {
      setState(() {
        _reminders.add(reminderData);
      });
    }
  }

  void _saveTracker() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    final trackerId = const Uuid().v4();
    final trackersDao = ref.read(trackersDaoProvider);
    final tagsDao = ref.read(tagsDaoProvider);
    final remindersDao = ref.read(remindersDaoProvider);

    await trackersDao.upsert(TrackersCompanion(
      id: drift.Value(trackerId),
      title: drift.Value(title),
      unit: drift.Value(_unitController.text.trim().isEmpty ? null : _unitController.text.trim()),
      valueType: drift.Value(_valueType),
      direction: drift.Value(_direction),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));

    for (final tagId in _selectedTagIds) {
      await tagsDao.attachToTracker(trackerId, tagId);
    }

    for (final reminderData in _reminders) {
      await remindersDao.upsert(RemindersCompanion(
        id: drift.Value(const Uuid().v4()),
        trackerId: drift.Value(trackerId),
        title: drift.Value(title),
        remindAt: drift.Value(reminderData.remindAt),
        recurrenceRule: drift.Value(reminderData.recurrenceRule),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
        isSent: const drift.Value(false),
        isActive: const drift.Value(true),
      ));
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Add Tracker'),
        prefixes: [
          FHeaderAction.x(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FTextField(
              label: const Text('Tracker Name'),
              hint: 'e.g. Weight, Daily Steps',
              control: FTextFieldControl.managed(controller: _titleController),
            ),
            const SizedBox(height: 24),
            FSelectGroup<TrackerValueType>(
              label: const Text('Value Type'),
              description: const Text('Should the tracked value be an integer or a decimal?'),
              control: FMultiValueControl.lifted(
                value: {_valueType},
                onChange: (values) {
                  if (values.isNotEmpty) {
                    setState(() => _valueType = values.first);
                  }
                },
              ),
              children: [
                FSelectGroupItemMixin.radio(
                  value: TrackerValueType.integer,
                  label: const Text('Integer'),
                ),
                FSelectGroupItemMixin.radio(
                  value: TrackerValueType.double,
                  label: const Text('Float'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FTextField(
              label: const Text('Units'),
              hint: 'e.g. kg, in, blank',
              control: FTextFieldControl.managed(controller: _unitController),
            ),
            const SizedBox(height: 24),
            FSelectGroup<TrackerDirection>(
              label: const Text('Goal Direction'),
              description: const Text('Do you want this number to be increasing or decreasing?'),
              control: FMultiValueControl.lifted(
                value: {_direction},
                onChange: (values) {
                  if (values.isNotEmpty) {
                    setState(() => _direction = values.first);
                  }
                },
              ),
              children: [
                FSelectGroupItemMixin.radio(
                  value: TrackerDirection.increasing,
                  label: const Text('Increasing'),
                ),
                FSelectGroupItemMixin.radio(
                  value: TrackerDirection.decreasing,
                  label: const Text('Decreasing'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reminders',
                  style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
                ),
                FButton.icon(
                  variant: FButtonVariant.ghost,
                  size: FButtonSizeVariant.sm,
                  onPress: _addReminder,
                  child: const Icon(FLucideIcons.plus),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_reminders.isEmpty)
              Text(
                'No reminders set',
                style: FTheme.of(context).typography.body.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
              )
            else
              Column(
                children: _reminders.asMap().entries.map((entry) {
                  final index = entry.key;
                  final reminder = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            reminder.recurrenceRule.toString(),
                            style: FTheme.of(context).typography.body.sm,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FButton.icon(
                          variant: FButtonVariant.ghost,
                          size: FButtonSizeVariant.sm,
                          onPress: () => setState(() => _reminders.removeAt(index)),
                          child: const Icon(FLucideIcons.trash),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tags',
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
                    return FBadge(
                      variant: isSelected ? FBadgeVariant.primary : FBadgeVariant.outline,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTagIds.remove(tag.id);
                            } else {
                              _selectedTagIds.add(tag.id);
                            }
                          });
                        },
                        child: Text(tag.name),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: _saveTracker,
                child: const Text('Save Tracker'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
