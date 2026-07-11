// tables/todos_table.dart
import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';
import '../converters/recurrence_rule_converter.dart';
import '../converters/enum_converters.dart';

class Todos extends Table with AuditColumns {
  TextColumn get id       => text()();
  TextColumn get title    => text()();
  TextColumn get notes    => text().nullable()();
  TextColumn get parentId => text().nullable().references(Todos, #id)();

  IntColumn get status   => intEnum<TodoStatus>()();
  IntColumn get priority => integer().nullable()();

  DateTimeColumn get dueAt    => dateTime().nullable()();
  DateTimeColumn get nextDueAt => dateTime().nullable()();

  BoolColumn get isRecurring =>
      boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceRule =>
      text().nullable().map(const RecurrenceRuleConverter())();

  IntColumn get workDuration => integer().nullable()();
  IntColumn get breakDuration => integer().nullable()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}