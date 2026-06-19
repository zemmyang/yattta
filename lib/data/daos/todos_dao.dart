// daos/todos_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/todos_table.dart';
import '../tables/tags_table.dart';
import '../tables/junction_tables.dart';

part 'todos_dao.g.dart';

@DriftAccessor(tables: [Todos, TodoTags, Tags])
class TodosDao extends DatabaseAccessor<AppDatabase>
    with _$TodosDaoMixin {
  TodosDao(super.db);

  // Fetch all non-deleted todos, newest first
  Stream<List<Todo>> watchAll() => (select(todos)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  // Fetch subtasks for a given parent
  Future<List<Todo>> getSubtasks(String parentId) =>
      (select(todos)
        ..where((t) =>
        t.parentId.equals(parentId) & t.deletedAt.isNull()))
          .get();

  // Upsert with updated_at stamp
  Future<void> upsert(TodosCompanion entry) => into(todos).insertOnConflictUpdate(
    entry.copyWith(updatedAt: Value(DateTime.now())),
  );

  // Soft delete
  Future<void> softDelete(String id) =>
      (update(todos)..where((t) => t.id.equals(id)))
          .write(TodosCompanion(deletedAt: Value(DateTime.now())));
}