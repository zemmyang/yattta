import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/widgets/note_editor.dart';
import 'package:yattta/presentation/pages/add_entry_page.dart';
import '../providers/database_providers.dart';
import 'tag_dialogs.dart';


enum TextEntryMode { brainDump, taskNotes, trackerLog }

class UnifiedTextEntryPage extends ConsumerStatefulWidget {
  final TextEntryMode mode;
  
  // Brain Dump fields
  final BrainDump? brainDump;
  
  // Task Notes fields
  final Task? task;
  final TaskLog? taskLog;
  
  // Tracker Log fields
  final Tracker? tracker;
  final TrackerLog? trackerLog;

  const UnifiedTextEntryPage.brainDump({super.key, this.brainDump})
      : mode = TextEntryMode.brainDump,
        task = null,
        taskLog = null,
        tracker = null,
        trackerLog = null;

  const UnifiedTextEntryPage.taskNotes({super.key, required this.task, this.taskLog})
      : mode = TextEntryMode.taskNotes,
        brainDump = null,
        tracker = null,
        trackerLog = null;

  const UnifiedTextEntryPage.trackerLog({super.key, required this.tracker, required this.trackerLog})
      : mode = TextEntryMode.trackerLog,
        brainDump = null,
        task = null,
        taskLog = null;

  @override
  ConsumerState<UnifiedTextEntryPage> createState() => _UnifiedTextEntryPageState();
}

class _UnifiedTextEntryPageState extends ConsumerState<UnifiedTextEntryPage> {
  late final TextEditingController _noteController;
  late final QuillController _quillController;
  late final TextEditingController _valueController;
  late DateTime _selectedDate;
  final Set<String> _selectedTagIds = {};
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    String initialNote = '';
    String initialValue = '';
    _selectedDate = DateTime.now();

    switch (widget.mode) {
      case TextEntryMode.brainDump:
        initialNote = widget.brainDump?.note ?? '';
        break;
      case TextEntryMode.taskNotes:
        initialNote = widget.taskLog?.notes ?? '';
        break;
      case TextEntryMode.trackerLog:
        initialNote = widget.trackerLog?.notes ?? '';
        _selectedDate = widget.trackerLog?.loggedAt ?? DateTime.now();
        if (widget.tracker != null && widget.trackerLog != null) {
          initialValue = widget.tracker!.valueType == TrackerValueType.integer
              ? widget.trackerLog!.value.toInt().toString()
              : widget.trackerLog!.value.toString();
        }
        break;
    }

    _noteController = TextEditingController(text: initialNote);
    _quillController = QuillController(
      document: loadNoteToDocument(initialNote),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _valueController = TextEditingController(text: initialValue);
  }

  String _getNoteText() => getNoteFromEditor(_noteController, _quillController);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && widget.mode == TextEntryMode.brainDump) {
      _loadBrainDumpTags();
      _initialized = true;
    }
  }

  Future<void> _loadBrainDumpTags() async {
    if (widget.brainDump != null) {
      final tagsDao = ref.read(tagsDaoProvider);
      final tags = await tagsDao.getTagsForBrainDump(widget.brainDump!.id);
      if (mounted) {
        setState(() {
          _selectedTagIds.addAll(tags.map((t) => t.id));
        });
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _quillController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    switch (widget.mode) {
      case TextEntryMode.brainDump:
        await _saveBrainDump();
        break;
      case TextEntryMode.taskNotes:
        await _saveTaskNotes();
        break;
      case TextEntryMode.trackerLog:
        await _saveTrackerLog();
        break;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _convertTo(EntryType type) async {
    final note = _getNoteText();
    if (note.isEmpty) return;

    // Optional: Save the brain dump first if it's being edited or created
    // and then mark it as reviewed if it's an existing one.
    if (widget.mode == TextEntryMode.brainDump && widget.brainDump != null) {
      await ref.read(brainDumpsDaoProvider).markAsReviewed(widget.brainDump!.id);
    }

    final tags = await _getSelectedTags();
    final title = _getInitialTitle(note);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AddEntryPage(
            type: type,
            initialTitle: title,
            initialNotes: note,
            initialTags: tags,
          ),
        ),
      );
    }
  }

  String _getInitialTitle(String note) {
    // Try to extract the first line as title
    try {
      if (note.startsWith('[')) {
        final List<dynamic> json = jsonDecode(note);
        final doc = Document.fromJson(json);
        final plainText = doc.toPlainText().trim();
        final firstLine = plainText.split('\n').first;
        return firstLine.length > 50 ? '${firstLine.substring(0, 47)}...' : firstLine;
      }
    } catch (_) {}
    final firstLine = note.split('\n').first;
    return firstLine.length > 50 ? '${firstLine.substring(0, 47)}...' : firstLine;
  }

  Future<List<Tag>> _getSelectedTags() async {
    final allTags = await ref.read(tagsDaoProvider).getAllTags();
    return allTags.where((t) => _selectedTagIds.contains(t.id)).toList();
  }

  void _showConversionMenu() {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('Convert to...'),
        body: const Text('What would you like to convert this brain dump into?'),
        actions: [
          FButton(
            onPress: () {
              Navigator.of(context).pop();
              _convertTo(EntryType.todo);
            },
            variant: FButtonVariant.outline,
            child: const Text('Todo'),
          ),
          FButton(
            onPress: () {
              Navigator.of(context).pop();
              _convertTo(EntryType.task);
            },
            variant: FButtonVariant.outline,
            child: const Text('Task'),
          ),
          FButton(
            onPress: () {
              Navigator.of(context).pop();
              _convertTo(EntryType.tracker);
            },
            variant: FButtonVariant.outline,
            child: const Text('Tracker'),
          ),
          FButton(
            onPress: () => Navigator.of(context).pop(),
            variant: FButtonVariant.ghost,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBrainDump() async {
    final note = _getNoteText();
    if (note.isEmpty) return;

    final brainDumpsDao = ref.read(brainDumpsDaoProvider);
    final tagsDao = ref.read(tagsDaoProvider);
    final id = widget.brainDump?.id ?? const Uuid().v4();

    if (widget.brainDump == null) {
      await brainDumpsDao.insertBrainDump(BrainDumpsCompanion(
        id: drift.Value(id),
        note: drift.Value(note),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ));
    } else {
      await brainDumpsDao.updateBrainDump(
        id,
        BrainDumpsCompanion(
          note: drift.Value(note),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
      await tagsDao.detachAllFromBrainDump(id);
    }

    for (final tagId in _selectedTagIds) {
      await tagsDao.attachToBrainDump(id, tagId);
    }
  }

  Future<void> _saveTaskNotes() async {
    final tasksDao = ref.read(tasksDaoProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logId = widget.taskLog?.id ?? const Uuid().v4();

    await tasksDao.logOccurrence(TaskLogsCompanion(
      id: drift.Value(logId),
      taskId: drift.Value(widget.task!.id),
      status: drift.Value(widget.taskLog?.status ?? TaskLogStatus.notDone),
      triggeredAt: drift.Value(widget.taskLog?.triggeredAt ?? today),
      notes: drift.Value(_getNoteText()),
      createdAt: drift.Value(widget.taskLog?.createdAt ?? DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));
  }

  Future<void> _saveTrackerLog() async {
    final value = double.tryParse(_valueController.text);
    if (value == null) return;

    await ref.read(trackersDaoProvider).updateLog(
          TrackerLogsCompanion(
            id: drift.Value(widget.trackerLog!.id),
            value: drift.Value(value),
            loggedAt: drift.Value(_selectedDate),
            notes: drift.Value(_getNoteText()),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    String title = '';
    String label = '';
    String hint = '';

    switch (widget.mode) {
      case TextEntryMode.brainDump:
        title = widget.brainDump == null ? 'Brain Dump' : 'Edit Brain Dump';
        label = 'Quick Note';
        hint = "What's on your mind?";
        break;
      case TextEntryMode.taskNotes:
        title = 'Task Notes';
        label = 'Notes for ${widget.task?.title}';
        hint = 'What happened today?';
        break;
      case TextEntryMode.trackerLog:
        title = 'Edit Log';
        label = 'Notes';
        hint = 'Add any details...';
        break;
    }

    return FScaffold(
      header: FHeader.nested(
        title: Text(title),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
        suffixes: [
          if (widget.mode == TextEntryMode.brainDump)
            FHeaderAction(
              icon: const Icon(FLucideIcons.arrowRightLeft),
              onPress: _showConversionMenu,
            ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.check),
            onPress: _save,
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.mode == TextEntryMode.trackerLog) ...[
              FTextField(
                label: const Text('Value'),
                control: FTextFieldControl.managed(controller: _valueController),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),
              Text(
                'Date & Time',
                style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FButton(
                variant: FButtonVariant.outline,
                onPress: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null && context.mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_selectedDate),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: Text(
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')} '
                  '${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 24),
            ],
            NoteEditor(
              label: label,
              hint: hint,
              textController: _noteController,
              quillController: _quillController,
            ),
            if (widget.mode == TextEntryMode.brainDump) ...[
              const SizedBox(height: 24),
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
              _buildBrainDumpTags(),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: _save,
                child: Text(widget.mode == TextEntryMode.trackerLog ? 'Save Changes' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrainDumpTags() {
    final tagsStream = ref.watch(tagsDaoProvider).watchAll();
    return StreamBuilder<List<Tag>>(
      stream: tagsStream,
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
    );
  }
}
