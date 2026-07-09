import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/utils/settings_controller.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/presentation/pages/reminder_dialogs.dart';
import 'package:yattta/presentation/widgets/note_editor.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:yattta/domain/models/recurrence_rule.dart';
import 'package:yattta/domain/sync/parsed_models.dart';

enum EntryType { task, todo, tracker }

class AddEntryPage extends ConsumerStatefulWidget {
  final EntryType type;
  final Task? task;
  final Todo? todo;
  final Tracker? tracker;
  final List<Reminder>? initialReminders;
  final List<Tag>? initialTags;
  final String? initialTitle;
  final String? initialNotes;

  const AddEntryPage({
    super.key,
    required this.type,
    this.task,
    this.todo,
    this.tracker,
    this.initialReminders,
    this.initialTags,
    this.initialTitle,
    this.initialNotes,
  });

  @override
  ConsumerState<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends ConsumerState<AddEntryPage> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  late final QuillController _quillController;
  final _workDurationController = TextEditingController();
  final _breakDurationController = TextEditingController();
  final _unitController = TextEditingController();
  
  final _selectedTagIds = <String>{};
  final List<ReminderData> _reminders = [];
  
  // Todo specific
  DateTime? _selectedDueDate;
  ParsedPriority _selectedPriority = ParsedPriority.normal;
  
  // Tracker specific
  TrackerValueType _valueType = TrackerValueType.integer;
  TrackerDirection _direction = TrackerDirection.increasing;

  @override
  void initState() {
    super.initState();
    String? initialNotes = widget.initialNotes;
    if (widget.type == EntryType.task) {
      initialNotes = widget.task?.notes ?? initialNotes;
    } else if (widget.type == EntryType.todo) {
      initialNotes = widget.todo?.notes ?? initialNotes;
    }
    else if (widget.type == EntryType.tracker) {
      initialNotes = widget.tracker?.notes ?? initialNotes;
    }

    _quillController = QuillController(
      document: loadNoteToDocument(initialNotes),
      selection: const TextSelection.collapsed(offset: 0),
    );

    if (widget.type == EntryType.task && widget.task != null) {
      _titleController.text = widget.task!.title;
      _notesController.text = widget.task!.notes ?? '';
    } else if (widget.type == EntryType.todo && widget.todo != null) {
      _titleController.text = widget.todo!.title;
      _notesController.text = widget.todo!.notes ?? '';
      _workDurationController.text = widget.todo!.workDuration?.toString() ?? '';
      _breakDurationController.text = widget.todo!.breakDuration?.toString() ?? '';
      _selectedDueDate = widget.todo!.dueAt;
      _selectedPriority = _toParsedPriority(widget.todo!.priority);
    } else if (widget.type == EntryType.tracker && widget.tracker != null) {
      _titleController.text = widget.tracker!.title;
      _notesController.text = widget.tracker!.notes ?? '';
      _unitController.text = widget.tracker!.unit ?? '';
      _valueType = widget.tracker!.valueType;
      _direction = widget.tracker!.direction;
    } else if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }

    if (widget.initialReminders != null) {
      _reminders.addAll(widget.initialReminders!.map((r) => ReminderData(
            remindAt: r.remindAt,
            recurrenceRule: r.recurrenceRule ?? const RecurrenceRule(frequency: 'none'),
          )));
    }

    if (widget.initialTags != null) {
      _selectedTagIds.addAll(widget.initialTags!.map((t) => t.id));
    }
  }

  ParsedPriority _toParsedPriority(int? p) {
    if (p == null) return ParsedPriority.normal;
    if (p <= 1) return ParsedPriority.low;
    if (p >= 3) return ParsedPriority.high;
    return ParsedPriority.normal;
  }

  int _fromParsedPriority(ParsedPriority p) {
    return switch (p) {
      ParsedPriority.low => 1,
      ParsedPriority.normal => 2,
      ParsedPriority.high => 3,
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _quillController.dispose();
    _workDurationController.dispose();
    _breakDurationController.dispose();
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final id = switch (widget.type) {
      EntryType.task => widget.task?.id,
      EntryType.todo => widget.todo?.id,
      EntryType.tracker => widget.tracker?.id,
    } ?? const Uuid().v4();

    final tagsDao = ref.read(tagsDaoProvider);
    final remindersDao = ref.read(remindersDaoProvider);
    final notes = getNoteFromEditor(_notesController, _quillController);

    switch (widget.type) {
      case EntryType.task:
        final tasksDao = ref.read(tasksDaoProvider);
        await tasksDao.upsert(TasksCompanion(
          id: drift.Value(id),
          title: drift.Value(title),
          notes: drift.Value(notes),
          isActive: drift.Value(widget.task?.isActive ?? true),
          createdAt: drift.Value(widget.task?.createdAt ?? DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
          recurrenceRule: drift.Value(widget.task?.recurrenceRule ?? const RecurrenceRule(frequency: 'none')),
        ));
        if (widget.task != null) {
          await tagsDao.detachAllFromTask(id);
          await remindersDao.deleteAllForTask(id);
        }
        for (final tagId in _selectedTagIds) {
          await tagsDao.attachToTask(id, tagId);
        }
        for (final reminderData in _reminders) {
          await remindersDao.upsert(RemindersCompanion(
            id: drift.Value(const Uuid().v4()),
            taskId: drift.Value(id),
            title: drift.Value(title),
            remindAt: drift.Value(reminderData.remindAt),
            recurrenceRule: drift.Value(reminderData.recurrenceRule),
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
            isSent: const drift.Value(false),
            isActive: const drift.Value(true),
          ));
        }
        break;
      case EntryType.todo:
        final todosDao = ref.read(todosDaoProvider);
        await todosDao.upsert(TodosCompanion(
          id: drift.Value(id),
          title: drift.Value(title),
          notes: drift.Value(notes),
          status: drift.Value(widget.todo?.status ?? TodoStatus.pending),
          dueAt: drift.Value(_selectedDueDate),
          priority: drift.Value(_fromParsedPriority(_selectedPriority)),
          workDuration: drift.Value(int.tryParse(_workDurationController.text)),
          breakDuration: drift.Value(int.tryParse(_breakDurationController.text)),
          createdAt: drift.Value(widget.todo?.createdAt ?? DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ));
        if (widget.todo != null) {
          await tagsDao.detachAllFromTodo(id);
          await remindersDao.deleteAllForTodo(id);
        }
        for (final tagId in _selectedTagIds) {
          await tagsDao.attachToTodo(id, tagId);
        }
        // Todo doesn't have reminders in the current UI, but we can add them easily now
        for (final reminderData in _reminders) {
          await remindersDao.upsert(RemindersCompanion(
            id: drift.Value(const Uuid().v4()),
            todoId: drift.Value(id),
            title: drift.Value(title),
            remindAt: drift.Value(reminderData.remindAt),
            recurrenceRule: drift.Value(reminderData.recurrenceRule),
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
            isSent: const drift.Value(false),
            isActive: const drift.Value(true),
          ));
        }
        break;
      case EntryType.tracker:
        final trackersDao = ref.read(trackersDaoProvider);
        await trackersDao.upsert(TrackersCompanion(
          id: drift.Value(id),
          title: drift.Value(title),
          notes: drift.Value(notes),
          unit: drift.Value(_unitController.text.trim().isEmpty ? null : _unitController.text.trim()),
          valueType: drift.Value(_valueType),
          direction: drift.Value(_direction),
          createdAt: drift.Value(widget.tracker?.createdAt ?? DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ));
        if (widget.tracker != null) {
          await tagsDao.detachAllFromTracker(id);
          await remindersDao.deleteAllForTracker(id);
        }
        for (final tagId in _selectedTagIds) {
          await tagsDao.attachToTracker(id, tagId);
        }
        for (final reminderData in _reminders) {
          await remindersDao.upsert(RemindersCompanion(
            id: drift.Value(const Uuid().v4()),
            trackerId: drift.Value(id),
            title: drift.Value(title),
            remindAt: drift.Value(reminderData.remindAt),
            recurrenceRule: drift.Value(reminderData.recurrenceRule),
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
            isSent: const drift.Value(false),
            isActive: const drift.Value(true),
          ));
        }
        break;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final entityName = widget.type.name.substring(0, 1).toUpperCase() + widget.type.name.substring(1);
    final confirm = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: Text('Delete $entityName'),
        body: Text('Are you sure you want to delete this $entityName? This will move it to the recycle bin.'),
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

    if (confirm == true && mounted) {
      final id = switch (widget.type) {
        EntryType.task => widget.task!.id,
        EntryType.todo => widget.todo!.id,
        EntryType.tracker => widget.tracker!.id,
      };

      switch (widget.type) {
        case EntryType.task:
          await ref.read(remindersDaoProvider).deleteAllForTask(id);
          await ref.read(tasksDaoProvider).softDelete(id);
          break;
        case EntryType.todo:
          await ref.read(todosDaoProvider).softDelete(id);
          break;
        case EntryType.tracker:
          await ref.read(trackersDaoProvider).softDelete(id);
          break;
      }
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entityName = widget.type.name.substring(0, 1).toUpperCase() + widget.type.name.substring(1);
    final isEdit = switch (widget.type) {
      EntryType.task => widget.task != null,
      EntryType.todo => widget.todo != null,
      EntryType.tracker => widget.tracker != null,
    };
    final isPowerUser = settingsController.userMode == UserMode.powerUser;

    return FScaffold(
      header: FHeader.nested(
        title: Text(isEdit ? 'Edit $entityName' : 'Add $entityName'),
        prefixes: [
          FHeaderAction.x(onPress: () => Navigator.of(context).pop()),
        ],
        suffixes: [
          if (isEdit)
            FHeaderAction(
              icon: const Icon(FLucideIcons.trash),
              onPress: _delete,
            ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FTextField(
              label: Text('$entityName Title'),
              hint: 'What needs to be done?',
              control: FTextFieldControl.managed(controller: _titleController),
            ),
            const SizedBox(height: 24),
            NoteEditor(
              label: 'Notes',
              hint: 'Add more details...',
              textController: _notesController,
              quillController: _quillController,
              maxLines: 5,
            ),
            
            // Todo specific fields
            if (widget.type == EntryType.todo) ...[
              const SizedBox(height: 24),
              _buildDueDateField(),
              if (isPowerUser) ...[
                const SizedBox(height: 24),
                _buildDurationFields(),
              ],
              const SizedBox(height: 24),
              _buildPriorityField(),
            ],

            // Tracker specific fields
            if (widget.type == EntryType.tracker) ...[
              const SizedBox(height: 24),
              _buildTrackerFields(),
            ],

            const SizedBox(height: 24),
            _buildRemindersSection(),
            const SizedBox(height: 24),
            _buildTagsSection(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: _save,
                child: Text(isEdit ? 'Update $entityName' : 'Save $entityName'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateField() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Due Date',
              style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              _selectedDueDate != null
                  ? '${_selectedDueDate!.year}-${_selectedDueDate!.month.toString().padLeft(2, '0')}-${_selectedDueDate!.day.toString().padLeft(2, '0')}'
                  : 'No due date',
              style: FTheme.of(context).typography.body.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
            ),
          ],
        ),
        Row(
          children: [
            if (_selectedDueDate != null)
              FButton.icon(
                variant: FButtonVariant.ghost,
                size: FButtonSizeVariant.sm,
                onPress: () => setState(() => _selectedDueDate = null),
                child: const Icon(FLucideIcons.x),
              ),
            FButton.icon(
              variant: FButtonVariant.outline,
              size: FButtonSizeVariant.sm,
              onPress: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDueDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (date != null) {
                  setState(() => _selectedDueDate = date);
                }
              },
              child: const Icon(FLucideIcons.calendar),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationFields() {
    return Row(
      children: [
        Expanded(
          child: FTextField(
            label: const Text('Work Duration (min)'),
            hint: 'Default: ${settingsController.timerDuration}',
            keyboardType: TextInputType.number,
            control: FTextFieldControl.managed(controller: _workDurationController),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FTextField(
            label: const Text('Break Duration (min)'),
            hint: 'Default: ${settingsController.breakDuration}',
            keyboardType: TextInputType.number,
            control: FTextFieldControl.managed(controller: _breakDurationController),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        FTabs(
          control: FTabControl.managed(
            initial: _selectedPriority.index,
            onChange: (index) {
              setState(() {
                _selectedPriority = ParsedPriority.values[index];
              });
            },
          ),
          children: [
            FTabEntry(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FLucideIcons.chevronDown, size: 16, color: Colors.blue[300]),
                  const SizedBox(width: 4),
                  const Text('Low'),
                ],
              ),
              child: const SizedBox.shrink(),
            ),
            const FTabEntry(
              label: Text('Normal'),
              child: SizedBox.shrink(),
            ),
            FTabEntry(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FLucideIcons.chevronUp, size: 16, color: Colors.red[300]),
                  const SizedBox(width: 4),
                  const Text('High'),
                ],
              ),
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrackerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildRemindersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
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
