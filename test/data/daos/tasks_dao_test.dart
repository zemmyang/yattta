import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/domain/models/recurrence_rule.dart';
import 'package:yattta/data/converters/enum_converters.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  group('TasksDao', () {
    const defaultRecurrence = RecurrenceRule(frequency: 'daily');

    test('upsert and watchAll', () async {
      final task = TasksCompanion.insert(
        id: 'task-1',
        title: 'Test Task',
        recurrenceRule: defaultRecurrence,
        updatedAt: Value(DateTime.now()),
      );

      await db.tasksDao.upsert(task);

      final results = await db.tasksDao.watchAll().first;
      expect(results.length, 1);
      expect(results[0].title, 'Test Task');
    });

    test('logOccurrence and getLogsForTask', () async {
      await db.tasksDao.upsert(TasksCompanion.insert(
        id: 'task-1',
        title: 'Test Task',
        recurrenceRule: defaultRecurrence,
        updatedAt: Value(DateTime.now()),
      ));

      final log = TaskLogsCompanion.insert(
        id: 'log-1',
        taskId: 'task-1',
        triggeredAt: DateTime.now(),
        status: TaskLogStatus.done,
      );

      await db.tasksDao.logOccurrence(log);

      final logs = await db.tasksDao.getLogsForTask('task-1');
      expect(logs.length, 1);
      expect(logs[0].id, 'log-1');
    });

    test('softDelete and watchDeleted', () async {
      await db.tasksDao.upsert(TasksCompanion.insert(
        id: 'task-1',
        title: 'Test Task',
        recurrenceRule: defaultRecurrence,
        updatedAt: Value(DateTime.now()),
      ));

      await db.tasksDao.softDelete('task-1');

      final active = await db.tasksDao.watchAll().first;
      expect(active, isEmpty);

      final deleted = await db.tasksDao.watchDeleted().first;
      expect(deleted.length, 1);
      expect(deleted[0].id, 'task-1');
    });
  });
}
