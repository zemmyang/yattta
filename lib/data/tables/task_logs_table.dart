import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';
import 'tasks_table.dart';
import "../converters/enum_converters.dart";

// Maps to the three possible log outcomes

class TaskLogs extends Table with AuditColumns {
  TextColumn get id          => text()();
  TextColumn get taskId      => text().references(Tasks, #id)();
  IntColumn  get status      => intEnum<TaskLogStatus>()();
  TextColumn get skipReason  => text().nullable()();
  DateTimeColumn get triggeredAt => dateTime()();
  TextColumn get notes       => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // Enforces that a task can only have one log per scheduled occurrence.
  // Supports sub-daily habits since we match on the exact datetime,
  // not just the date.
  @override
  List<Set<Column>> get uniqueKeys => [
    {taskId, triggeredAt},
  ];
}