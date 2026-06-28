import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';
import 'todos_table.dart';
import 'tasks_table.dart';
import "../converters/enum_converters.dart";

class PomodoroSessions extends Table with AuditColumns {
  TextColumn     get id              => text()();
  // Optional link to a todo — a session can be free-floating
  TextColumn     get todoId          => text().nullable().references(Todos, #id)();
  // Optional link to a task
  TextColumn     get taskId          => text().nullable().references(Tasks, #id)();
  IntColumn      get durationSeconds => integer()(); // planned duration
  DateTimeColumn get startedAt       => dateTime()();
  DateTimeColumn get endedAt         => dateTime().nullable()();
  IntColumn      get status          => intEnum<PomodoroStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}