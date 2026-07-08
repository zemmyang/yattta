import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/utils/notification_service.dart';
import 'package:yattta/utils/settings_controller.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/converters/enum_converters.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';
import 'package:yattta/presentation/pages/add_todo.dart';
import 'package:yattta/presentation/pages/unified_text_entry.dart';
import 'package:yattta/presentation/pages/todo_details.dart';
import 'package:yattta/presentation/pages/brain_dump_dialogs.dart';

class TodosPage extends ConsumerWidget {
  final VoidCallback? onMenuPressed;

  const TodosPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Todos'),
        prefixes: [
          if (onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: onMenuPressed!,
            ),
        ],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.lightbulb),
            onPress: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const UnifiedTextEntryPage.brainDump()),
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Main(),
          Positioned(
            bottom: 16,
            right: 16,
            child: FButton.icon(
              onPress: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddTodoPage()),
              ),
              child: const Icon(FLucideIcons.plus),
            ),
          ),
        ],
      ),
    );
  }
}

enum TimerMode { work, shortBreak, longBreak }

class Main extends ConsumerStatefulWidget {
  const Main({super.key});

  @override
  ConsumerState<Main> createState() => _MainState();
}

class _MainState extends ConsumerState<Main> {
  late int _timeLeft; // in seconds
  Timer? _timer;
  bool _isPaused = false;
  TimerMode _timerMode = TimerMode.work;
  int _sessionsCompleted = 0;
  Todo? _focusedTodo;
  DateTime? _sessionStartedAt;

  int get _currentDurationMinutes {
    switch (_timerMode) {
      case TimerMode.work:
        return _focusedTodo?.workDuration ?? settingsController.timerDuration;
      case TimerMode.shortBreak:
        return _focusedTodo?.breakDuration ?? settingsController.breakDuration;
      case TimerMode.longBreak:
        return settingsController.longBreakDuration;
    }
  }

  @override
  void initState() {
    super.initState();
    _timeLeft = _currentDurationMinutes * 60;
    settingsController.addListener(_onSettingsControllerChange);
  }

  void _onSettingsControllerChange() {
    if (_timer == null || !_timer!.isActive) {
      setState(() {
        _timeLeft = _currentDurationMinutes * 60;
      });
    }
  }

  void _startTimer() {
    NotificationService().requestPermissions();
    _timer?.cancel();
    setState(() {
      _timeLeft = _currentDurationMinutes * 60;
      _isPaused = false;
      if (_timerMode == TimerMode.work) {
        _sessionStartedAt = DateTime.now();
      } else {
        _sessionStartedAt = null;
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isPaused) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            _finishSession();
          }
        });
      }
    });
  }

  void _finishSession() {
    _timer?.cancel();

    final finishedMode = _timerMode;
    if (finishedMode == TimerMode.work && _sessionStartedAt != null) {
      _savePomodoroSession();
    }

    setState(() {
      _timer = null;
      _isPaused = false;
      String title;
      String body;
      bool shouldAutoStart = false;

      if (finishedMode == TimerMode.work) {
        _sessionsCompleted++;
        if (_sessionsCompleted % settingsController.sessionsUntilLongBreak == 0) {
          _timerMode = TimerMode.longBreak;
          title = 'Work Finished';
          body = 'Great job! Time for a long break. Ready for ${settingsController.longBreakDuration} minutes?';
        } else {
          _timerMode = TimerMode.shortBreak;
          title = 'Work Finished';
          body = 'Time for a break! Ready for ${settingsController.breakDuration} minutes?';
        }
        shouldAutoStart = settingsController.autoStartBreaks;
      } else {
        _timerMode = TimerMode.work;
        title = finishedMode == TimerMode.shortBreak ? 'Short Break Finished' : 'Long Break Finished';
        body = 'Break over! Ready to focus for ${settingsController.timerDuration} minutes?';
        shouldAutoStart = settingsController.autoStartWork;
      }

      _timeLeft = _currentDurationMinutes * 60;

      NotificationService().showTimerFinishedNotification(
        title: title,
        body: body,
      );

      if (_timerMode == TimerMode.longBreak) {
        final brainDumps = ref.read(unreviewedBrainDumpsProvider).value ?? [];
        if (brainDumps.isNotEmpty) {
          showBrainDumpReviewDialog(context, ref);
        }
      }

      if (shouldAutoStart) {
        _startTimer();
      }
    });
  }

  void _togglePause() {
    if (_timer == null || !(_timer!.isActive) || _timeLeft <= 0) return;
    setState(() => _isPaused = !_isPaused);
  }

  @override
  void dispose() {
    settingsController.removeListener(_onSettingsControllerChange);
    _timer?.cancel();
    super.dispose();
  }

  String _getModeLabel() {
    switch (_timerMode) {
      case TimerMode.work:
        return 'WORK';
      case TimerMode.shortBreak:
        return 'SHORT BREAK';
      case TimerMode.longBreak:
        return 'LONG BREAK';
    }
  }

  Color _getTimerColor(BuildContext context) {
    switch (_timerMode) {
      case TimerMode.work:
        return FTheme.of(context).colors.primary;
      case TimerMode.shortBreak:
        return Colors.green;
      case TimerMode.longBreak:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todosProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth * 0.8
                : constraints.maxHeight * 0.8)
            .clamp(0.0, 400.0);
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                    const SizedBox(height: 20),
                    Text(
                      _getModeLabel(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: size * 0.1,
                        color: _getTimerColor(context),
                      ),
                    ),
                    if (_timerMode == TimerMode.work) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Session ${(_sessionsCompleted % settingsController.sessionsUntilLongBreak) + 1} of ${settingsController.sessionsUntilLongBreak}',
                        style: TextStyle(
                          fontSize: size * 0.05,
                          color: FTheme.of(context).colors.mutedForeground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_focusedTodo != null) ...[
                      Text(
                        _focusedTodo!.title,
                        style: FTheme.of(context).typography.body.lg.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      width: size,
                      height: size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: _timeLeft / (_currentDurationMinutes * 60),
                              strokeWidth: size * 0.05,
                              backgroundColor: FTheme.of(context).colors.border,
                              valueColor: AlwaysStoppedAnimation(_getTimerColor(context)),
                            ),
                          ),
                          Text(
                            '${(_timeLeft ~/ 60).toString().padLeft(2, '0')}:${(_timeLeft % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: size * 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (_timer == null)
                      SizedBox(
                        width: size * 0.9,
                        child: FButton(
                          onPress: _startTimer,
                          suffix: const Icon(FLucideIcons.play),
                          child: const Text('Start'),
                        ),
                      )
                    else ...[
                      SizedBox(
                        width: size * 0.9,
                        child: FButton(
                          onPress: _togglePause,
                          suffix: Icon(_isPaused ? FLucideIcons.play : FLucideIcons.pause),
                          child: Text(_isPaused ? 'Resume' : 'Pause'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: size * 0.9,
                        child: FButton(
                          variant: FButtonVariant.outline,
                          onPress: _finishSession,
                          suffix: const Icon(FLucideIcons.squareStop),
                          child: const Text('Stop'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: todosAsync.when(
                        data: (todos) {
                          final pendingTodos = todos.where((t) => t.todo.status != TodoStatus.done).toList();
                          final doneTodos = todos.where((t) => t.todo.status == TodoStatus.done).toList();
                          
                          if (pendingTodos.isEmpty && doneTodos.isEmpty) {
                            return const SizedBox();
                          }
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pendingTodos.isNotEmpty) ...[
                                Text(
                                  'PENDING',
                                  style: FTheme.of(context).typography.body.sm.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: FTheme.of(context).colors.mutedForeground,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                ReorderableListView.builder(
                                  buildDefaultDragHandles: false,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: pendingTodos.length,
                                  onReorderItem: (oldIndex, newIndex) {
                                    final item = pendingTodos.removeAt(oldIndex);
                                    pendingTodos.insert(newIndex, item);
                                    ref.read(todosDaoProvider).updatePositions(
                                          pendingTodos.map((t) => t.todo.id).toList(),
                                        );
                                  },
                                  itemBuilder: (context, index) {
                                    final item = pendingTodos[index];
                                    final isFocused = _focusedTodo?.id == item.todo.id;
                                    return Container(
                                      key: ValueKey(item.todo.id),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: index < pendingTodos.length - 1
                                              ? BorderSide(color: FTheme.of(context).colors.border, width: 0.5)
                                              : BorderSide.none,
                                        ),
                                      ),
                                      child: FTile(
                                        selected: isFocused,
                                        onPress: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => TodoDetailsPage(
                                              todo: item.todo,
                                              tags: item.tags,
                                              onFocus: (t) => setState(() => _focusedTodo = t),
                                            ),
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  if (item.todo.priority != null && item.todo.priority != 2) ...[
                                                    PriorityBadge(priority: item.todo.priority!),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  Expanded(child: Text(item.todo.title)),
                                                ],
                                              ),
                                            ),
                                            StreamBuilder<int>(
                                              stream: ref.read(pomodoroSessionsDaoProvider).watchCountForTodo(item.todo.id),
                                              builder: (context, snapshot) {
                                                final count = snapshot.data ?? 0;
                                                if (count == 0) return const SizedBox();
                                                return Padding(
                                                  padding: const EdgeInsets.only(left: 8),
                                                  child: FBadge(
                                                    variant: FBadgeVariant.secondary,
                                                    child: Text('$count 🍅'),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (item.todo.dueAt != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4, bottom: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      FLucideIcons.calendar,
                                                      size: 14,
                                                      color: item.todo.dueAt!.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                                                          ? Colors.red
                                                          : FTheme.of(context).colors.mutedForeground,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${item.todo.dueAt!.year}-${item.todo.dueAt!.month.toString().padLeft(2, '0')}-${item.todo.dueAt!.day.toString().padLeft(2, '0')}',
                                                      style: FTheme.of(context).typography.body.xs.copyWith(
                                                            color: item.todo.dueAt!.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                                                                ? Colors.red
                                                                : FTheme.of(context).colors.mutedForeground,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (item.tags.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Wrap(
                                                  spacing: 4,
                                                  runSpacing: 4,
                                                  children: item.tags
                                                      .map((tag) => TagBadge(tag: tag))
                                                  .toList(),
                                                ),
                                              ),
                                          ],
                                        ),
                                        prefix: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Padding(
                                                padding: EdgeInsets.only(right: 8),
                                                child: Icon(FLucideIcons.gripVertical, size: 20),
                                              ),
                                            ),
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _toggleTodoStatus(item.todo, true),
                                              child: FCheckbox(
                                                value: false,
                                                onChange: (value) => _toggleTodoStatus(item.todo, value),
                                              ),
                                            ),
                                          ],
                                        ),
                                        suffix: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FButton.icon(
                                              variant: FButtonVariant.ghost,
                                              size: FButtonSizeVariant.sm,
                                              onPress: () => setState(() => _focusedTodo = item.todo),
                                              child: Icon(
                                                FLucideIcons.target,
                                                color: isFocused ? FTheme.of(context).colors.primary : null,
                                              ),
                                            ),
                                            FButton.icon(
                                              variant: FButtonVariant.ghost,
                                              size: FButtonSizeVariant.sm,
                                              onPress: () => Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) => AddTodoPage(
                                                    todo: item.todo,
                                                    initialTags: item.tags,
                                                  ),
                                                ),
                                              ),
                                              child: const Icon(FLucideIcons.pencil),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (doneTodos.isNotEmpty) ...[
                                Text(
                                  'DONE',
                                  style: FTheme.of(context).typography.body.sm.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: FTheme.of(context).colors.mutedForeground,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                ReorderableListView.builder(
                                  buildDefaultDragHandles: false,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: doneTodos.length,
                                  onReorderItem: (oldIndex, newIndex) {
                                    final item = doneTodos.removeAt(oldIndex);
                                    doneTodos.insert(newIndex, item);
                                    ref.read(todosDaoProvider).updatePositions(
                                          doneTodos.map((t) => t.todo.id).toList(),
                                        );
                                  },
                                  itemBuilder: (context, index) {
                                    final item = doneTodos[index];
                                    final isFocused = _focusedTodo?.id == item.todo.id;
                                    return Container(
                                      key: ValueKey(item.todo.id),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: index < doneTodos.length - 1
                                              ? BorderSide(color: FTheme.of(context).colors.border, width: 0.5)
                                              : BorderSide.none,
                                        ),
                                      ),
                                      child: FTile(
                                        selected: isFocused,
                                        onPress: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => TodoDetailsPage(
                                              todo: item.todo,
                                              tags: item.tags,
                                              onFocus: (t) => setState(() => _focusedTodo = t),
                                            ),
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  if (item.todo.priority != null && item.todo.priority != 2) ...[
                                                    PriorityBadge(
                                                      priority: item.todo.priority!,
                                                      isDone: true,
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      item.todo.title,
                                                      style: const TextStyle(
                                                        decoration: TextDecoration.lineThrough,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            StreamBuilder<int>(
                                              stream: ref.read(pomodoroSessionsDaoProvider).watchCountForTodo(item.todo.id),
                                              builder: (context, snapshot) {
                                                final count = snapshot.data ?? 0;
                                                if (count == 0) return const SizedBox();
                                                return Padding(
                                                  padding: const EdgeInsets.only(left: 8),
                                                  child: FBadge(
                                                    variant: FBadgeVariant.outline,
                                                    child: Text('$count 🍅'),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (item.todo.dueAt != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4, bottom: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      FLucideIcons.calendar,
                                                      size: 14,
                                                      color: FTheme.of(context).colors.mutedForeground,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${item.todo.dueAt!.year}-${item.todo.dueAt!.month.toString().padLeft(2, '0')}-${item.todo.dueAt!.day.toString().padLeft(2, '0')}',
                                                      style: FTheme.of(context).typography.body.xs.copyWith(
                                                            color: FTheme.of(context).colors.mutedForeground,
                                                            decoration: TextDecoration.lineThrough,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (item.tags.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Wrap(
                                                  spacing: 4,
                                                  runSpacing: 4,
                                                  children: item.tags
                                                      .map((tag) => TagBadge(
                                                            tag: tag,
                                                            variant: FBadgeVariant.outline,
                                                          ))
                                                      .toList(),
                                                ),
                                              ),
                                          ],
                                        ),
                                        prefix: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Padding(
                                                padding: EdgeInsets.only(right: 8),
                                                child: Icon(FLucideIcons.gripVertical, size: 20),
                                              ),
                                            ),
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _toggleTodoStatus(item.todo, false),
                                              child: FCheckbox(
                                                value: true,
                                                onChange: (value) => _toggleTodoStatus(item.todo, value),
                                              ),
                                            ),
                                          ],
                                        ),
                                        suffix: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FButton.icon(
                                              variant: FButtonVariant.ghost,
                                              size: FButtonSizeVariant.sm,
                                              onPress: () => setState(() => _focusedTodo = item.todo),
                                              child: Icon(
                                                FLucideIcons.target,
                                                color: isFocused ? FTheme.of(context).colors.primary : null,
                                              ),
                                            ),
                                            FButton.icon(
                                              variant: FButtonVariant.ghost,
                                              size: FButtonSizeVariant.sm,
                                              onPress: () => Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) => AddTodoPage(
                                                    todo: item.todo,
                                                    initialTags: item.tags,
                                                  ),
                                                ),
                                              ),
                                              child: const Icon(FLucideIcons.pencil),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Text('Error: $err'),
                      ),
                    ),
                    const SizedBox(height: 80), // Bottom padding for FAB
                  ],
                ),
              ),
            ),
          );
        },
    );
  }

  void _toggleTodoStatus(Todo todo, bool value) async {
    final todosDao = ref.read(todosDaoProvider);
    await todosDao.upsert(todo.toCompanion(true).copyWith(
          status: drift.Value(value ? TodoStatus.done : TodoStatus.pending),
          updatedAt: drift.Value(DateTime.now()),
        ));
  }

  void _savePomodoroSession() async {
    final dao = ref.read(pomodoroSessionsDaoProvider);
    await dao.insertSession(PomodoroSessionsCompanion.insert(
      id: const Uuid().v4(),
      todoId: drift.Value(_focusedTodo?.id),
      durationSeconds: _currentDurationMinutes * 60,
      startedAt: _sessionStartedAt ?? DateTime.now(),
      endedAt: drift.Value(DateTime.now()),
      status: PomodoroStatus.completed,
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));
  }
}

class PriorityBadge extends StatelessWidget {
  final int priority;
  final bool isDone;

  const PriorityBadge({required this.priority, this.isDone = false, super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      1 => Colors.blue[300], // Low
      3 => Colors.red[300],  // High
      _ => null,
    };

    if (color == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDone ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDone ? color.withValues(alpha: 0.5) : color,
          width: 1,
        ),
      ),
      child: Text(
        priority == 1 ? 'LOW' : 'HIGH',
        style: FTheme.of(context).typography.body.xs.copyWith(
              color: isDone ? color.withValues(alpha: 0.7) : color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
      ),
    );
  }
}
