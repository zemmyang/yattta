import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:drift/drift.dart' as drift;

import 'package:yattta/domain/models/recurrence_rule.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/presentation/pages/reminder_dialogs.dart';

class AddTaskPage extends ConsumerStatefulWidget {
  const AddTaskPage({super.key});

  @override
  ConsumerState<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends ConsumerState<AddTaskPage> {
  final _titleController = TextEditingController();
  final List<ReminderData> _reminders = [];
  final Set<String> _selectedTagIds = {};

  @override
  void dispose() {
    _titleController.dispose();
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

  void _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      // Show error toaster if title is empty
      return;
    }

    final taskId = const Uuid().v4();
    final tasksDao = ref.read(tasksDaoProvider);
    final remindersDao = ref.read(remindersDaoProvider);
    final tagsDao = ref.read(tagsDaoProvider);

    await tasksDao.upsert(TasksCompanion(
      id: drift.Value(taskId),
      title: drift.Value(title),
      isActive: const drift.Value(true),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
      recurrenceRule: const drift.Value(RecurrenceRule(frequency: 'none')),
    ));

    for (final reminderData in _reminders) {
      await remindersDao.upsert(RemindersCompanion(
        id: drift.Value(const Uuid().v4()),
        taskId: drift.Value(taskId),
        title: drift.Value(title),
        remindAt: drift.Value(reminderData.remindAt),
        recurrenceRule: drift.Value(reminderData.recurrenceRule),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
        isSent: const drift.Value(false),
        isActive: const drift.Value(true),
      ));
    }

    for (final tagId in _selectedTagIds) {
      await tagsDao.attachToTask(taskId, tagId);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsStream = ref.watch(tagsDaoProvider).watchAll();

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Add Task'),
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
              label: const Text('Task Title'),
              hint: 'What needs to be done?',
              control: FTextFieldControl.managed(controller: _titleController),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reminders',
                  style: FTheme.of(context).typography.lg.copyWith(fontWeight: FontWeight.bold),
                ),
                FButton.icon(
                  variant: FButtonVariant.outline,
                  onPress: _addReminder,
                  child: const Icon(FLucideIcons.plus),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_reminders.isEmpty)
              Text(
                'No reminders set',
                style: FTheme.of(context).typography.sm.copyWith(color: FTheme.of(context).colors.mutedForeground),
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
                            style: FTheme.of(context).typography.sm,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FButton.icon(
                          variant: FButtonVariant.ghost,
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
                  style: FTheme.of(context).typography.lg.copyWith(fontWeight: FontWeight.bold),
                ),
                FButton.icon(
                  variant: FButtonVariant.outline,
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
              stream: tagsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    'No tags available',
                    style: FTheme.of(context).typography.sm.copyWith(color: FTheme.of(context).colors.mutedForeground),
                  );
                }

                final tags = snapshot.data!;
                return FSelectGroup<String>(
                  label: const Text('Select Tags'),
                  control: FMultiValueControl.lifted(
                    value: _selectedTagIds,
                    onChange: (values) {
                      setState(() {
                        _selectedTagIds.clear();
                        _selectedTagIds.addAll(values);
                      });
                    },
                  ),
                  children: tags.map((tag) => FSelectGroupItemMixin.checkbox(
                    value: tag.id,
                    label: Text(tag.name),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: _saveTask,
                child: const Text('Save Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
