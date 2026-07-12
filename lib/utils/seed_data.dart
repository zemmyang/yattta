import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../data/database/app_database.dart';
import '../data/converters/enum_converters.dart';
import '../domain/models/recurrence_rule.dart';

class DataSeeder {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  final Random _random = Random();

  DataSeeder(this.db);

  Future<void> seed({bool massiveSessions = false}) async {
    // 1. Tags
    final tags = await _seedTags();

    // 2. Todos (including priorities, subtasks, and soft-deleted)
    await _seedTodos(tags);

    // 3. Tasks (Recurring Habits)
    await _seedTasks(tags);

    // 4. Trackers (including historical logs for charts)
    await _seedTrackers(tags);

    // 5. Brain Dumps
    await _seedBrainDumps(tags);

    // 6. Pomodoro Sessions
    await _seedPomodoroSessions(massive: massiveSessions);

    // 7. Timers
    await _seedTimers(tags);

    // 8. Settings
    await _seedSettings();
  }

  Future<List<String>> _seedTags() async {
    final tagData = [
      {'name': 'Work', 'color': '#3B82F6'}, // Blue
      {'name': 'Personal', 'color': '#10B981'}, // Green
      {'name': 'Health', 'color': '#EF4444'}, // Red
      {'name': 'Learning', 'color': '#8B5CF6'}, // Violet
      {'name': 'Urgent', 'color': '#F59E0B'}, // Orange
      {'name': 'Home', 'color': '#EC4899'}, // Pink
      {'name': 'Finance', 'color': '#059669'}, // Emerald
    ];

    final ids = <String>[];
    for (final data in tagData) {
      final id = _uuid.v4();
      ids.add(id);
      await db.tagsDao.upsert(TagsCompanion.insert(
        id: id,
        name: data['name'] as String,
        color: Value(data['color'] as String),
      ));
    }
    return ids;
  }

  Future<void> _seedTodos(List<String> tagIds) async {
    final now = DateTime.now();

    // Regular Todo
    final t1Id = _uuid.v4();
    await db.todosDao.upsert(TodosCompanion.insert(
      id: t1Id,
      title: 'Complete project proposal',
      notes: const Value('Draft the initial scope and budget for the new app.'),
      status: TodoStatus.inProgress,
      priority: const Value(1),
      dueAt: Value(now.add(const Duration(days: 2))),
    ));
    await db.tagsDao.attachToTodo(t1Id, tagIds[0]); // Work
    await db.tagsDao.attachToTodo(t1Id, tagIds[4]); // Urgent

    // Todo with Pomodoro settings & Reminder
    final tPomoId = _uuid.v4();
    await db.todosDao.upsert(TodosCompanion.insert(
      id: tPomoId,
      title: 'Implement Auth Service',
      notes: const Value('Add Firebase Auth integration.'),
      status: TodoStatus.pending,
      priority: const Value(1),
      workDuration: const Value(50),
      breakDuration: const Value(10),
      dueAt: Value(now.add(const Duration(hours: 8))),
    ));
    await db.tagsDao.attachToTodo(tPomoId, tagIds[0]); // Work
    await db.remindersDao.upsert(RemindersCompanion.insert(
      id: _uuid.v4(),
      todoId: Value(tPomoId),
      remindAt: now.add(const Duration(hours: 7)),
      title: const Value('Time to work on Auth Service!'),
    ));

    // Todo with subtasks
    final parentId = _uuid.v4();
    await db.todosDao.upsert(TodosCompanion.insert(
      id: parentId,
      title: 'Plan weekend trip',
      status: TodoStatus.pending,
      priority: const Value(2),
    ));
    await db.tagsDao.attachToTodo(parentId, tagIds[1]); // Personal

    await db.todosDao.upsert(TodosCompanion.insert(
      id: _uuid.v4(),
      title: 'Book hotel',
      parentId: Value(parentId),
      status: TodoStatus.done,
    ));
    await db.todosDao.upsert(TodosCompanion.insert(
      id: _uuid.v4(),
      title: 'Pack bags',
      parentId: Value(parentId),
      status: TodoStatus.pending,
    ));

    // High Priority Todo
    final t3Id = _uuid.v4();
    await db.todosDao.upsert(TodosCompanion.insert(
      id: t3Id,
      title: 'Call the bank',
      status: TodoStatus.pending,
      priority: const Value(0), // Highest priority
      dueAt: Value(now.add(const Duration(hours: 4))),
    ));
    await db.tagsDao.attachToTodo(t3Id, tagIds[4]); // Urgent
    await db.tagsDao.attachToTodo(t3Id, tagIds[6]); // Finance

    // Multi-tag Todo
    final t4Id = _uuid.v4();
    await db.todosDao.upsert(TodosCompanion.insert(
      id: t4Id,
      title: 'Clean the kitchen',
      status: TodoStatus.pending,
      priority: const Value(3),
    ));
    await db.tagsDao.attachToTodo(t4Id, tagIds[5]); // Home
    await db.tagsDao.attachToTodo(t4Id, tagIds[1]); // Personal

    // Soft deleted Todo
    final tDeletedId = _uuid.v4();
    await db.todosDao.upsert(TodosCompanion.insert(
      id: tDeletedId,
      title: 'Old groceries list',
      status: TodoStatus.done,
      deletedAt: Value(now.subtract(const Duration(days: 1))),
    ));
  }

  Future<void> _seedTasks(List<String> tagIds) async {
    final now = DateTime.now();

    // Daily Habit: Meditation
    final task1Id = _uuid.v4();
    final task1CreatedAt = now.subtract(const Duration(days: 30));
    await db.tasksDao.upsert(TasksCompanion.insert(
      id: task1Id,
      title: 'Morning Meditation',
      notes: const Value('10 minutes of mindfulness.'),
      recurrenceRule: const RecurrenceRule(frequency: 'daily'),
      createdAt: Value(task1CreatedAt),
      nextDueAt: Value(DateTime(now.year, now.month, now.day, 8, 0).add(const Duration(days: 1))),
    ));
    await db.tagsDao.attachToTask(task1Id, tagIds[2]); // Health
    
    // Reminder for meditation
    await db.remindersDao.upsert(RemindersCompanion.insert(
      id: _uuid.v4(),
      taskId: Value(task1Id),
      remindAt: DateTime(now.year, now.month, now.day, 7, 50).add(const Duration(days: 1)),
      title: const Value('Prepare for meditation'),
    ));

    // Seed logs for meditation
    for (int i = 1; i <= 14; i++) {
      final logDate = now.subtract(Duration(days: i));
      if (logDate.isBefore(task1CreatedAt)) continue;

      await db.tasksDao.logOccurrence(TaskLogsCompanion.insert(
        id: _uuid.v4(),
        taskId: task1Id,
        status: i % 7 == 0 ? TaskLogStatus.notDone : TaskLogStatus.done,
        triggeredAt: logDate,
      ));
    }

    // Weekly Habit: Review
    final task2Id = _uuid.v4();
    await db.tasksDao.upsert(TasksCompanion.insert(
      id: task2Id,
      title: 'Weekly Review',
      recurrenceRule: const RecurrenceRule(frequency: 'weekly', weekDays: [7]), // Sunday
      nextDueAt: Value(DateTime(now.year, now.month, now.day + (7 - now.weekday))),
    ));
    await db.tagsDao.attachToTask(task2Id, tagIds[0]); // Work

    // Daily Habit: Reading
    final task3Id = _uuid.v4();
    await db.tasksDao.upsert(TasksCompanion.insert(
      id: task3Id,
      title: 'Read 20 pages',
      recurrenceRule: const RecurrenceRule(frequency: 'daily'),
      nextDueAt: Value(DateTime(now.year, now.month, now.day, 21, 0)),
    ));
    await db.tagsDao.attachToTask(task3Id, tagIds[3]); // Learning

    // Soft deleted Task
    final taskDeletedId = _uuid.v4();
    await db.tasksDao.upsert(TasksCompanion.insert(
      id: taskDeletedId,
      title: 'Obsolete habit',
      recurrenceRule: const RecurrenceRule(frequency: 'daily'),
      deletedAt: Value(now),
    ));
  }

  Future<void> _seedTrackers(List<String> tagIds) async {
    final now = DateTime.now();

    // 1. Water Intake (Integer)
    final tracker1Id = _uuid.v4();
    await db.trackersDao.upsert(TrackersCompanion.insert(
      id: tracker1Id,
      title: 'Water Intake',
      unit: const Value('glasses'),
      valueType: const Value(TrackerValueType.integer),
      createdAt: Value(now.subtract(const Duration(days: 45))),
    ));
    await db.tagsDao.attachToTracker(tracker1Id, tagIds[2]); // Health
    
    // Nudge for water
    await db.remindersDao.upsert(RemindersCompanion.insert(
      id: _uuid.v4(),
      trackerId: Value(tracker1Id),
      remindAt: now.add(const Duration(hours: 2)),
      title: const Value('Drink some water!'),
      recurrenceRule: Value(const RecurrenceRule(frequency: 'daily')),
    ));

    // 2. Weight (Double)
    final tracker2Id = _uuid.v4();
    await db.trackersDao.upsert(TrackersCompanion.insert(
      id: tracker2Id,
      title: 'Weight',
      unit: const Value('kg'),
      valueType: const Value(TrackerValueType.double),
      direction: const Value(TrackerDirection.decreasing),
      createdAt: Value(now.subtract(const Duration(days: 60))),
    ));
    await db.tagsDao.attachToTracker(tracker2Id, tagIds[2]); // Health

    // 3. Pushups (Counter)
    final tracker3Id = _uuid.v4();
    await db.trackersDao.upsert(TrackersCompanion.insert(
      id: tracker3Id,
      title: 'Pushups',
      unit: const Value('reps'),
      valueType: const Value(TrackerValueType.integer),
      createdAt: Value(now.subtract(const Duration(days: 10))),
    ));
    await db.tagsDao.attachToTracker(tracker3Id, tagIds[2]); // Health

    // Seed logs for charts
    // 1. Water Intake (last 30 days)
    for (int i = 30; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final tracker1 = await (db.select(db.trackers)..where((t) => t.id.equals(tracker1Id))).getSingle();
      if (date.isBefore(tracker1.createdAt)) continue;

      await db.trackersDao.addLog(TrackerLogsCompanion.insert(
        id: _uuid.v4(),
        trackerId: tracker1Id,
        value: (_random.nextInt(7) + 4).toDouble(),
        loggedAt: date,
      ));
    }

    // 2. Weight (last 30 days)
    for (int i = 30; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final tracker2 = await (db.select(db.trackers)..where((t) => t.id.equals(tracker2Id))).getSingle();
      if (date.isBefore(tracker2.createdAt)) continue;

      await db.trackersDao.addLog(TrackerLogsCompanion.insert(
        id: _uuid.v4(),
        trackerId: tracker2Id,
        value: 80.0 - (30 - i) * 0.15 + (_random.nextDouble() - 0.5),
        loggedAt: date,
      ));
    }

    // 3. Pushups (last 10 days, matching tracker age)
    for (int i = 10; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final tracker3 = await (db.select(db.trackers)..where((t) => t.id.equals(tracker3Id))).getSingle();
      if (date.isBefore(tracker3.createdAt)) continue;

      if (i % 2 == 0) {
        await db.trackersDao.addLog(TrackerLogsCompanion.insert(
          id: _uuid.v4(),
          trackerId: tracker3Id,
          value: (10 + (10 - i)).toDouble(),
          loggedAt: date,
        ));
      }
    }

    // Soft deleted Tracker
    final trackerDeletedId = _uuid.v4();
    await db.trackersDao.upsert(TrackersCompanion.insert(
      id: trackerDeletedId,
      title: 'Retired Tracker',
      deletedAt: Value(now),
    ));
  }

  Future<void> _seedBrainDumps(List<String> tagIds) async {
    final now = DateTime.now();

    final b1Id = _uuid.v4();
    await db.brainDumpsDao.insertBrainDump(BrainDumpsCompanion.insert(
      id: b1Id,
      note: 'I should try that new pizza place on 5th street.',
    ));
    await db.tagsDao.attachToBrainDump(b1Id, tagIds[1]); // Personal

    await db.brainDumpsDao.insertBrainDump(BrainDumpsCompanion.insert(
      id: _uuid.v4(),
      note: 'Idea for a sci-fi novel where time flows backwards.',
    ));

    // Reviewed brain dump
    final bReviewedId = _uuid.v4();
    await db.brainDumpsDao.insertBrainDump(BrainDumpsCompanion.insert(
      id: bReviewedId,
      note: 'This was a good idea but I already did it.',
      isReviewed: const Value(true),
    ));

    // Soft deleted brain dump
    final bDeletedId = _uuid.v4();
    await db.brainDumpsDao.insertBrainDump(BrainDumpsCompanion.insert(
      id: bDeletedId,
      note: 'Delete me later.',
      deletedAt: Value(now),
    ));
  }

  Future<void> _seedPomodoroSessions({bool massive = false}) async {
    final now = DateTime.now();
    final todoIds = await (db.select(db.todos)..where((t) => t.deletedAt.isNull())).get().then((list) => list.map((e) => e.id).toList());
    
    if (massive) {
      // Seed sessions for the last 90 days
      for (int i = 0; i < 90; i++) {
        final day = now.subtract(Duration(days: i));
        // Random number of sessions per day (0 to 8)
        final sessionsCount = _random.nextInt(9);
        for (int j = 0; j < sessionsCount; j++) {
          final start = DateTime(day.year, day.month, day.day, 8 + _random.nextInt(12), _random.nextInt(60));
          
          // Randomly decide if it's a to-do session or free-floating
          final type = _random.nextInt(2);
          String? todoId;
          
          if (type == 0 && todoIds.isNotEmpty) {
            todoId = todoIds[_random.nextInt(todoIds.length)];
          }

          await db.pomodoroSessionsDao.insertSession(PomodoroSessionsCompanion.insert(
            id: _uuid.v4(),
            todoId: todoId != null ? Value(todoId) : const Value.absent(),
            durationSeconds: 1500, // 25 mins
            startedAt: start,
            endedAt: Value(start.add(const Duration(minutes: 25))),
            status: PomodoroStatus.completed,
          ));
        }
      }
      return;
    }

    // Some successful sessions
    for (int i = 0; i < 5; i++) {
      await db.pomodoroSessionsDao.insertSession(PomodoroSessionsCompanion.insert(
        id: _uuid.v4(),
        todoId: todoIds.isNotEmpty ? Value(todoIds[_random.nextInt(todoIds.length)]) : const Value.absent(),
        durationSeconds: 1500, // 25 mins
        startedAt: now.subtract(Duration(hours: 2 * i + 1)),
        endedAt: Value(now.subtract(Duration(hours: 2 * i + 1)).add(const Duration(minutes: 25))),
        status: PomodoroStatus.completed,
      ));
    }

    // One failed session
    await db.pomodoroSessionsDao.insertSession(PomodoroSessionsCompanion.insert(
      id: _uuid.v4(),
      durationSeconds: 1500,
      startedAt: now.subtract(const Duration(minutes: 40)),
      endedAt: Value(now.subtract(const Duration(minutes: 30))),
      status: PomodoroStatus.abandoned,
    ));
  }

  Future<void> _seedTimers(List<String> tagIds) async {
    final now = DateTime.now();

    // 1. Active Timer: Pasta
    final t1Id = _uuid.v4();
    await db.timersDao.upsert(TimersCompanion.insert(
      id: t1Id,
      label: const Value('Pasta'),
      durationSeconds: 600, // 10 mins
      startedAt: now.subtract(const Duration(minutes: 3)),
    ));
    await db.tagsDao.attachToTimer(t1Id, tagIds[5]); // Home

    // 2. Active Timer: Deep Work
    final t2Id = _uuid.v4();
    await db.timersDao.upsert(TimersCompanion.insert(
      id: t2Id,
      label: const Value('Deep Work'),
      durationSeconds: 3000, // 50 mins
      startedAt: now.subtract(const Duration(minutes: 25)),
    ));
    await db.tagsDao.attachToTimer(t2Id, tagIds[0]); // Work

    // 3. Finished Timer: Quick Nap
    final t3Id = _uuid.v4();
    await db.timersDao.upsert(TimersCompanion.insert(
      id: t3Id,
      label: const Value('Quick Nap'),
      durationSeconds: 600, // 10 mins
      startedAt: now.subtract(const Duration(minutes: 15)),
    ));

    // 4. Cancelled Timer: Workout
    final t4Id = _uuid.v4();
    await db.timersDao.upsert(TimersCompanion.insert(
      id: t4Id,
      label: const Value('Workout'),
      durationSeconds: 1800, // 30 mins
      startedAt: now.subtract(const Duration(hours: 1)),
      isCancelled: const Value(true),
    ));
    await db.tagsDao.attachToTimer(t4Id, tagIds[2]); // Health

    // 5. Soft Deleted Timer: Laundry
    final t5Id = _uuid.v4();
    await db.timersDao.upsert(TimersCompanion.insert(
      id: t5Id,
      label: const Value('Laundry'),
      durationSeconds: 3600, // 60 mins
      startedAt: now.subtract(const Duration(hours: 2)),
      deletedAt: Value(now),
    ));
  }

  Future<void> _seedSettings() async {
    final settings = [
      {'key': 'theme_mode', 'value': 'system'},
      {'key': 'pomodoro_work_duration', 'value': '25'},
      {'key': 'pomodoro_break_duration', 'value': '5'},
      {'key': 'sync_enabled', 'value': 'false'},
    ];

    for (final s in settings) {
      await db.settingsDao.setString(
        s['key']!,
        s['value']!,
      );
    }
  }
}
