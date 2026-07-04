import 'package:drift/drift.dart';
import 'todos_table.dart';
import 'tasks_table.dart';
import 'trackers_table.dart';
import 'tags_table.dart';
import 'brain_dumps_table.dart';

class TodoTags extends Table {
  TextColumn get todoId => text().references(Todos, #id)();
  TextColumn get tagId  => text().references(Tags,  #id)();

  @override
  Set<Column> get primaryKey => {todoId, tagId};
}

class TaskTags extends Table {
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get tagId  => text().references(Tags,  #id)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

class TrackerTags extends Table {
  TextColumn get trackerId => text().references(Trackers, #id)();
  TextColumn get tagId     => text().references(Tags,     #id)();

  @override
  Set<Column> get primaryKey => {trackerId, tagId};
}

class BrainDumpTags extends Table {
  TextColumn get brainDumpId => text().references(BrainDumps, #id)();
  TextColumn get tagId       => text().references(Tags,       #id)();

  @override
  Set<Column> get primaryKey => {brainDumpId, tagId};
}
