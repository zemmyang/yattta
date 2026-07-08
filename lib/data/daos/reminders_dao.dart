import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/reminders_table.dart';

part 'reminders_dao.g.dart';

@DriftAccessor(tables: [Reminders])
class RemindersDao extends DatabaseAccessor<AppDatabase>
    with _$RemindersDaoMixin {
  RemindersDao(super.db);

  // Watch all active, unsent reminders due before a given time
  Stream<List<Reminder>> watchDue(DateTime before) => (select(reminders)
    ..where((r) =>
    r.deletedAt.isNull() &
    r.isActive.equals(true) &
    r.isSent.equals(false) &
    r.remindAt.isSmallerOrEqualValue(before)))
      .watch();

  Future<List<Reminder>> getForTodo(String todoId) =>
      (select(reminders)
        ..where((r) =>
        r.todoId.equals(todoId) & r.deletedAt.isNull()))
          .get();

  Future<List<Reminder>> getForTask(String taskId) =>
      (select(reminders)
        ..where((r) =>
        r.taskId.equals(taskId) & r.deletedAt.isNull()))
          .get();

  Future<List<Reminder>> getForTracker(String trackerId) =>
      (select(reminders)
        ..where((r) =>
        r.trackerId.equals(trackerId) & r.deletedAt.isNull()))
          .get();

  Stream<List<Reminder>> watchAllActive() => (select(reminders)
        ..where((r) => r.deletedAt.isNull() & r.isActive.equals(true)))
      .watch();

  Future<void> markSent(String id) =>
      (update(reminders)..where((r) => r.id.equals(id)))
          .write(RemindersCompanion(
        isSent: const Value(true),
        updatedAt: Value(DateTime.now()),
      ));

  void _assertSingleTarget(RemindersCompanion entry) {
    final count = [
      entry.todoId.present    && entry.todoId.value    != null,
      entry.taskId.present    && entry.taskId.value    != null,
      entry.trackerId.present && entry.trackerId.value != null,
    ].where((b) => b).length;

    if (count != 1) {
      throw ArgumentError(
        'A reminder must reference exactly one of: todoId, taskId, trackerId. '
            'Got $count non-null values.',
      );
    }
  }

  Future<void> upsert(RemindersCompanion entry) {
    _assertSingleTarget(entry);
    return into(reminders).insertOnConflictUpdate(
      entry.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteAllForTask(String taskId) =>
      (delete(reminders)..where((r) => r.taskId.equals(taskId))).go();

  Future<void> deleteAllForTodo(String todoId) =>
      (delete(reminders)..where((r) => r.todoId.equals(todoId))).go();

  Future<void> deleteAllForTracker(String trackerId) =>
      (delete(reminders)..where((r) => r.trackerId.equals(trackerId))).go();

  Future<void> softDelete(String id) =>
      (update(reminders)..where((r) => r.id.equals(id)))
          .write(RemindersCompanion(deletedAt: Value(DateTime.now())));
}