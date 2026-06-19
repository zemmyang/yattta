import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';
import 'trackers_table.dart';

class TrackerLogs extends Table with AuditColumns {
  TextColumn     get id        => text()();
  TextColumn     get trackerId => text().references(Trackers, #id)();
  RealColumn     get value     => real()();
  DateTimeColumn get loggedAt  => dateTime()();
  TextColumn     get notes     => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}