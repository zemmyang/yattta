import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';

class BrainDumps extends Table with AuditColumns {
  TextColumn get id => text()();
  TextColumn get note => text()();
  BoolColumn get isReviewed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
