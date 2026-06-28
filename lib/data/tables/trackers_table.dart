import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';
import "../converters/enum_converters.dart";

class Trackers extends Table with AuditColumns {
  TextColumn   get id        => text()();
  TextColumn   get title     => text()();
  TextColumn   get unit      => text().nullable()(); // e.g. 'kg', 'km', 'glasses'
  RealColumn   get goalValue => real().nullable()();
  IntColumn    get goalType  => intEnum<GoalType>().nullable()();
  IntColumn    get valueType => intEnum<TrackerValueType>().withDefault(const Constant(0))(); // Default to integer
  IntColumn    get direction => intEnum<TrackerDirection>().withDefault(const Constant(0))(); // Default to increasing
  TextColumn   get notes     => text().nullable()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  // No recurrence fields here — scheduling is delegated to Reminders

  @override
  Set<Column> get primaryKey => {id};
}