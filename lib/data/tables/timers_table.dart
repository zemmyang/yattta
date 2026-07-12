import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';

@DataClassName('TimerEntry')
class Timers extends Table with AuditColumns {
  TextColumn get id => text()();
  TextColumn get label => text().nullable()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get startedAt => dateTime()();
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
