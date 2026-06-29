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

class AddTodoPage extends ConsumerStatefulWidget {
  final Todo? todo;
  final List<Tag>? initialTags;

  const AddTodoPage({super.key, this.todo, this.initialTags});

  @override
  ConsumerState<AddTodoPage> createState() => _AddTodoPageState();
}

class _AddTodoPageState extends ConsumerState<AddTodoPage> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _workDurationController = TextEditingController();
  final _breakDurationController = TextEditingController();
  final _selectedTagIds = <String>{};
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    if (widget.todo != null) {
      _titleController.text = widget.todo!.title;
      _notesController.text = widget.todo!.notes ?? '';
      _workDurationController.text = widget.todo!.workDuration?.toString() ?? '';
      _breakDurationController.text = widget.todo!.breakDuration?.toString() ?? '';
      _selectedDueDate = widget.todo!.dueAt;
      if (widget.initialTags != null) {
        _selectedTagIds.addAll(widget.initialTags!.map((t) => t.id));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _workDurationController.dispose();
    _breakDurationController.dispose();
    super.dispose();
  }

  void _saveTodo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final todosDao = ref.read(todosDaoProvider);
    final tagsDao = ref.read(tagsDaoProvider);
    final todoId = widget.todo?.id ?? const Uuid().v4();

    await todosDao.upsert(TodosCompanion(
      id: drift.Value(todoId),
      title: drift.Value(title),
      notes: drift.Value(_notesController.text.trim()),
      status: drift.Value(widget.todo?.status ?? TodoStatus.pending),
      dueAt: drift.Value(_selectedDueDate),
      workDuration: drift.Value(int.tryParse(_workDurationController.text)),
      breakDuration: drift.Value(int.tryParse(_breakDurationController.text)),
      createdAt: drift.Value(widget.todo?.createdAt ?? DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));

    if (widget.todo != null) {
      await tagsDao.detachAllFromTodo(todoId);
    }

    for (final tagId in _selectedTagIds) {
      await tagsDao.attachToTodo(todoId, tagId);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _deleteTodo() async {
    if (widget.todo == null) return;

    final confirm = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('Delete Todo'),
        body: const Text('Are you sure you want to move this todo to the recycle bin?'),
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
      await ref.read(todosDaoProvider).softDelete(widget.todo!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPowerUser = settingsController.userMode == UserMode.powerUser;

    return FScaffold(
      header: FHeader.nested(
        title: Text(widget.todo == null ? 'Add Todo' : 'Edit Todo'),
        prefixes: [
          FHeaderAction.x(onPress: () => Navigator.of(context).pop()),
        ],
        suffixes: [
          if (widget.todo != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.trash),
              onPress: _deleteTodo,
            ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FTextField(
              label: const Text('Todo Title'),
              hint: 'What needs to be done?',
              control: FTextFieldControl.managed(controller: _titleController),
            ),
            const SizedBox(height: 24),
            FTextField(
              label: const Text('Notes'),
              hint: 'Add more details...',
              maxLines: 5,
              control: FTextFieldControl.managed(controller: _notesController),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Due Date',
                      style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (_selectedDueDate != null)
                      Text(
                        '${_selectedDueDate!.year}-${_selectedDueDate!.month.toString().padLeft(2, '0')}-${_selectedDueDate!.day.toString().padLeft(2, '0')}',
                        style: FTheme.of(context).typography.body.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
                      )
                    else
                      Text(
                        'No due date',
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
            ),
            if (isPowerUser) ...[
              const SizedBox(height: 24),
              Row(
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
              ),
            ],
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: _saveTodo,
                child: const Text('Save Todo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
