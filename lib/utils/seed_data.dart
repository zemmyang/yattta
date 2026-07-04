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

  Future<void> seed() async {
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
  }

  Future<List<String>> _seedTags() async {
    final tagData = [
      {'name': 'Work', 'color': '#3B82F6'}, // Blue
      {'name': 'Personal', 'color': '#10B981'}, // Green
      {'name': 'Health', 'color': '#EF4444'}, // Red
      {'name': 'Learning', 'color': '#8B5CF6'}, // Violet
      {'name': 'Urgent', 'color': '#F59E0B'}, // Orange
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

    // Daily Habit
    final task1Id = _uuid.v4();
    await db.tasksDao.upsert(TasksCompanion.insert(
      id: task1Id,
      title: 'Morning Meditation',
      notes: const Value('10 minutes of mindfulness.'),
      recurrenceRule: const RecurrenceRule(frequency: 'daily'),
      nextDueAt: Value(DateTime(now.year, now.month, now.day, 8, 0)),
    ));
    await db.tagsDao.attachToTask(task1Id, tagIds[2]); // Health

    // Seed some logs for the habit
    for (int i = 1; i <= 5; i++) {
      await db.tasksDao.logOccurrence(TaskLogsCompanion.insert(
        id: _uuid.v4(),
        taskId: task1Id,
        status: TaskLogStatus.done,
        triggeredAt: now.subtract(Duration(days: i)),
      ));
    }

    // Weekly Habit
    final task2Id = _uuid.v4();
    await db.tasksDao.upsert(TasksCompanion.insert(
      id: task2Id,
      title: 'Weekly Review',
      recurrenceRule: const RecurrenceRule(frequency: 'weekly', weekDays: [7]), // Sunday
      nextDueAt: Value(DateTime(now.year, now.month, now.day + (7 - now.weekday))),
    ));
    await db.tagsDao.attachToTask(task2Id, tagIds[0]); // Work

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
      goalValue: const Value(8.0),
      goalType: const Value(GoalType.atLeast),
      valueType: const Value(TrackerValueType.integer),
    ));
    await db.tagsDao.attachToTracker(tracker1Id, tagIds[2]); // Health

    // 2. Weight (Double)
    final tracker2Id = _uuid.v4();
    await db.trackersDao.upsert(TrackersCompanion.insert(
      id: tracker2Id,
      title: 'Weight',
      unit: const Value('kg'),
      goalValue: const Value(75.0),
      goalType: const Value(GoalType.atMost),
      valueType: const Value(TrackerValueType.double),
      direction: const Value(TrackerDirection.decreasing),
    ));
    await db.tagsDao.attachToTracker(tracker2Id, tagIds[2]); // Health

    // Seed 30 days of logs for charts
    for (int i = 30; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      
      // Water: random 4-10 glasses
      await db.trackersDao.addLog(TrackerLogsCompanion.insert(
        id: _uuid.v4(),
        trackerId: tracker1Id,
        value: (_random.nextInt(7) + 4).toDouble(),
        loggedAt: date,
      ));

      // Weight: slightly fluctuating down from 80kg
      await db.trackersDao.addLog(TrackerLogsCompanion.insert(
        id: _uuid.v4(),
        trackerId: tracker2Id,
        value: 80.0 - (30 - i) * 0.1 + (_random.nextDouble() - 0.5),
        loggedAt: date,
      ));
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
}
