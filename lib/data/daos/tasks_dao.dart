import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/tasks_table.dart';
import '../tables/task_logs_table.dart';
import '../tables/tags_table.dart';
import '../tables/junction_tables.dart';

part 'tasks_dao.g.dart';

class TaskWithTags {
  final Task task;
  final List<Tag> tags;

  TaskWithTags({required this.task, required this.tags});
}

@DriftAccessor(tables: [Tasks, TaskLogs, TaskTags, Tags])
class TasksDao extends DatabaseAccessor<AppDatabase>
    with _$TasksDaoMixin {
  TasksDao(super.db);

  // Watch all active tasks
  Stream<List<Task>> watchAll() => (select(tasks)
    ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true))
    ..orderBy([(t) => OrderingTerm.asc(t.position), (t) => OrderingTerm.asc(t.nextDueAt)]))
      .watch();

  // Watch all deleted tasks
  Stream<List<Task>> watchDeleted() => (select(tasks)
    ..where((t) => t.deletedAt.isNotNull())
    ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
      .watch();

  Stream<List<TaskWithTags>> watchAllWithTags() {
    final tasksStream = (select(tasks)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.position), (t) => OrderingTerm.asc(t.title)]))
        .watch();
        
    return tasksStream.asyncMap((taskList) async {
      final List<TaskWithTags> results = [];
      for (final task in taskList) {
        final tags = await (select(db.tags).join([
          innerJoin(db.taskTags, db.taskTags.tagId.equalsExp(db.tags.id)),
        ])..where(db.taskTags.taskId.equals(task.id)))
            .map((row) => row.readTable(db.tags))
            .get();
        results.add(TaskWithTags(task: task, tags: tags));
      }
      return results;
    });
  }

  // Get all logs for a task, most recent first
  Future<List<TaskLog>> getLogsForTask(String taskId) =>
      (select(taskLogs)
        ..where((l) => l.taskId.equals(taskId))
        ..orderBy([(l) => OrderingTerm.desc(l.triggeredAt)]))
          .get();

  // Watch logs for a task within a date range (useful for habit history views)
  Stream<List<TaskLog>> watchLogsInRange(
      String taskId,
      DateTime from,
      DateTime to,
      ) =>
      (select(taskLogs)
        ..where((l) =>
        l.taskId.equals(taskId) &
        l.triggeredAt.isBetweenValues(from, to)))
          .watch();

  Future<void> upsert(TasksCompanion entry) {
    final toInsert = entry.updatedAt.present
        ? entry
        : entry.copyWith(updatedAt: Value(DateTime.now()));
    return into(tasks).insertOnConflictUpdate(toInsert);
  }

  Future<void> logOccurrence(TaskLogsCompanion entry) =>
      into(taskLogs).insertOnConflictUpdate(entry);

  // Watch logs for today for all tasks
  Stream<List<TaskLog>> watchLogsForDay(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(taskLogs)
      ..where((l) => l.triggeredAt.isBetweenValues(start, end)))
        .watch();
  }

  Future<void> deleteLog(String id) =>
      (delete(taskLogs)..where((l) => l.id.equals(id))).go();

  Future<void> softDelete(String id) =>
      (update(tasks)..where((t) => t.id.equals(id)))
          .write(TasksCompanion(deletedAt: Value(DateTime.now())));

  Future<void> restore(String id) =>
      (update(tasks)..where((t) => t.id.equals(id)))
          .write(const TasksCompanion(deletedAt: Value(null)));

  Future<void> hardDelete(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<void> updatePositions(List<String> ids) async {
    await batch((batch) {
      for (int i = 0; i < ids.length; i++) {
        batch.update(tasks, TasksCompanion(position: Value(i)),
            where: (t) => t.id.equals(ids[i]));
      }
    });
  }
}