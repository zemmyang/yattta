import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/tags_table.dart';
import '../tables/junction_tables.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [Tags, TodoTags, TaskTags, TrackerTags, BrainDumpTags, TimerTags])
class TagsDao extends DatabaseAccessor<AppDatabase>
    with _$TagsDaoMixin {
  TagsDao(super.db);

  Stream<List<Tag>> watchAll() => (select(tags)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  Future<List<Tag>> getAllTags() => (select(tags)
    ..where((t) => t.deletedAt.isNull()))
      .get();

  Stream<List<Tag>> watchDeleted() => (select(tags)
    ..where((t) => t.deletedAt.isNotNull())
    ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
      .watch();

  Future<List<Tag>> getTagsForTodo(String todoId) {
    final query = select(tags).join([
      innerJoin(todoTags, todoTags.tagId.equalsExp(tags.id)),
    ])..where(todoTags.todoId.equals(todoId));

    return query.map((row) => row.readTable(tags)).get();
  }

  Future<List<Tag>> getTagsForTask(String taskId) {
    final query = select(tags).join([
      innerJoin(taskTags, taskTags.tagId.equalsExp(tags.id)),
    ])..where(taskTags.taskId.equals(taskId));

    return query.map((row) => row.readTable(tags)).get();
  }

  Future<List<Tag>> getTagsForTracker(String trackerId) {
    final query = select(tags).join([
      innerJoin(trackerTags, trackerTags.tagId.equalsExp(tags.id)),
    ])..where(trackerTags.trackerId.equals(trackerId));

    return query.map((row) => row.readTable(tags)).get();
  }

  Future<List<Tag>> getTagsForBrainDump(String brainDumpId) {
    final query = select(tags).join([
      innerJoin(brainDumpTags, brainDumpTags.tagId.equalsExp(tags.id)),
    ])..where(brainDumpTags.brainDumpId.equals(brainDumpId));

    return query.map((row) => row.readTable(tags)).get();
  }

  Future<List<Tag>> getTagsForTimer(String timerId) {
    final query = select(tags).join([
      innerJoin(timerTags, timerTags.tagId.equalsExp(tags.id)),
    ])..where(timerTags.timerId.equals(timerId));

    return query.map((row) => row.readTable(tags)).get();
  }

  Future<void> upsert(TagsCompanion entry) =>
      into(tags).insertOnConflictUpdate(
        entry.copyWith(updatedAt: Value(DateTime.now())),
      );

  Future<void> attachToTodo(String todoId, String tagId) =>
      into(todoTags).insertOnConflictUpdate(
        TodoTagsCompanion.insert(todoId: todoId, tagId: tagId),
      );

  Future<void> attachToTask(String taskId, String tagId) =>
      into(taskTags).insertOnConflictUpdate(
        TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
      );

  Future<void> attachToTracker(String trackerId, String tagId) =>
      into(trackerTags).insertOnConflictUpdate(
        TrackerTagsCompanion.insert(trackerId: trackerId, tagId: tagId),
      );

  Future<void> attachToBrainDump(String brainDumpId, String tagId) =>
      into(brainDumpTags).insertOnConflictUpdate(
        BrainDumpTagsCompanion.insert(brainDumpId: brainDumpId, tagId: tagId),
      );

  Future<void> attachToTimer(String timerId, String tagId) =>
      into(timerTags).insertOnConflictUpdate(
        TimerTagsCompanion.insert(timerId: timerId, tagId: tagId),
      );

  Future<void> detachAllFromTodo(String todoId) =>
      (delete(todoTags)..where((t) => t.todoId.equals(todoId))).go();

  Future<void> detachAllFromTask(String taskId) =>
      (delete(taskTags)..where((t) => t.taskId.equals(taskId))).go();

  Future<void> detachAllFromTracker(String trackerId) =>
      (delete(trackerTags)..where((t) => t.trackerId.equals(trackerId))).go();

  Future<void> detachAllFromBrainDump(String brainDumpId) =>
      (delete(brainDumpTags)..where((t) => t.brainDumpId.equals(brainDumpId))).go();

  Future<void> detachAllFromTimer(String timerId) =>
      (delete(timerTags)..where((t) => t.timerId.equals(timerId))).go();

  Future<void> detachFromTodo(String todoId, String tagId) =>
      (delete(todoTags)
        ..where((t) =>
        t.todoId.equals(todoId) & t.tagId.equals(tagId)))
          .go();

  Future<void> softDelete(String id) =>
      (update(tags)..where((t) => t.id.equals(id)))
          .write(TagsCompanion(deletedAt: Value(DateTime.now())));

  Future<void> restore(String id) =>
      (update(tags)..where((t) => t.id.equals(id)))
          .write(const TagsCompanion(deletedAt: Value(null)));

  Future<void> hardDelete(String id) =>
      (delete(tags)..where((t) => t.id.equals(id))).go();
}