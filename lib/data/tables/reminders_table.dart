import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';
import '../converters/recurrence_rule_converter.dart';
import 'todos_table.dart';
import 'tasks_table.dart';
import 'trackers_table.dart';

class Reminders extends Table with AuditColumns {
  TextColumn get id => text()();

  // Exactly one of these three must be non-null (enforced below)
  TextColumn get todoId     => text().nullable().references(Todos,    #id)();
  TextColumn get taskId     => text().nullable().references(Tasks,    #id)();
  TextColumn get trackerId  => text().nullable().references(Trackers, #id)();

  TextColumn     get title       => text().nullable()();
  DateTimeColumn get remindAt    => dateTime()();

  // Only populated for tracker reminders (scheduled nudges)
  TextColumn     get recurrenceRule =>
      text().nullable().map(const RecurrenceRuleConverter())();
  DateTimeColumn get nextDueAt   => dateTime().nullable()();

  BoolColumn get isSent =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  // Raw SQL CHECK constraint — SQLite enforces this at the DB level.
  // The boolean arithmetic trick counts non-null FKs; must equal exactly 1.
  @override
  List<String> get customConstraints => [
    'CHECK ('
        '(todo_id IS NOT NULL) + '
        '(task_id IS NOT NULL) + '
        '(tracker_id IS NOT NULL) = 1'
        ')',
  ];
}