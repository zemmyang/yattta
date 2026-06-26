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
  const AddTodoPage({super.key});

  @override
  ConsumerState<AddTodoPage> createState() => _AddTodoPageState();
}

class _AddTodoPageState extends ConsumerState<AddTodoPage> {
  final _titleController = TextEditingController();
  final _workDurationController = TextEditingController();
  final _breakDurationController = TextEditingController();
  final _selectedTagIds = <String>{};

  @override
  void dispose() {
    _titleController.dispose();
    _workDurationController.dispose();
    _breakDurationController.dispose();
    super.dispose();
  }

  void _saveTodo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final todosDao = ref.read(todosDaoProvider);
    final tagsDao = ref.read(tagsDaoProvider);
    final todoId = const Uuid().v4();

    await todosDao.upsert(TodosCompanion(
      id: drift.Value(todoId),
      title: drift.Value(title),
      status: const drift.Value(TodoStatus.pending),
      workDuration: drift.Value(int.tryParse(_workDurationController.text)),
      breakDuration: drift.Value(int.tryParse(_breakDurationController.text)),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));

    for (final tagId in _selectedTagIds) {
      await tagsDao.attachToTodo(todoId, tagId);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPowerUser = settingsController.userMode == UserMode.powerUser;

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Add Todo'),
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
              label: const Text('Todo Title'),
              hint: 'What needs to be done?',
              control: FTextFieldControl.managed(controller: _titleController),
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
                  style: FTheme.of(context).typography.sm.copyWith(fontWeight: FontWeight.bold),
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
                    style: FTheme.of(context).typography.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
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
