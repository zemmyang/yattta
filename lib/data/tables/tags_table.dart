import 'package:drift/drift.dart';
import '../mixins/audit_columns.dart';

class Tags extends Table with AuditColumns {
  TextColumn get id    => text()();
  TextColumn get name  => text().customConstraint('NOT NULL UNIQUE COLLATE NOCASE')();
  TextColumn get color => text().nullable()(); // store hex string e.g. '#FF5733'

  @override
  Set<Column> get primaryKey => {id};
}