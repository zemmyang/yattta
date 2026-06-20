import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/tags_table.dart';
import '../tables/junction_tables.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [Tags, TodoTags, TaskTags, TrackerTags])
class TagsDao extends DatabaseAccessor<AppDatabase>
    with _$TagsDaoMixin {
  TagsDao(super.db);

  Stream<List<Tag>> watchAll() => (select(tags)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.asc(t.name)]))
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

  Future<void> detachFromTodo(String todoId, String tagId) =>
      (delete(todoTags)
        ..where((t) =>
        t.todoId.equals(todoId) & t.tagId.equals(tagId)))
          .go();

  Future<void> softDelete(String id) =>
      (update(tags)..where((t) => t.id.equals(id)))
          .write(TagsCompanion(deletedAt: Value(DateTime.now())));
}