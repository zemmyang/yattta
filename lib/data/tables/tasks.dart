// tables/tasks_table.dart  (formerly habits)
import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';
import '../converters/recurrence_rule_converter.dart';

class Tasks extends Table with AuditColumns {
  TextColumn get id             => text()();
  TextColumn get title          => text()();
  TextColumn get notes          => text().nullable()();
  TextColumn get recurrenceRule =>
      text().map(const RecurrenceRuleConverter())();
  DateTimeColumn get nextDueAt  => dateTime().nullable()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}