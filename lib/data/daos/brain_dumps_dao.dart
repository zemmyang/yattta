import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/brain_dumps_table.dart';

part 'brain_dumps_dao.g.dart';

@DriftAccessor(tables: [BrainDumps])
class BrainDumpsDao extends DatabaseAccessor<AppDatabase> with _$BrainDumpsDaoMixin {
  BrainDumpsDao(super.db);

  Stream<List<BrainDump>> watchUnreviewed() => (select(brainDumps)
        ..where((t) => t.isReviewed.equals(false) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Stream<List<BrainDump>> watchAll() => (select(brainDumps)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Stream<List<BrainDump>> watchDeleted() => (select(brainDumps)
        ..where((t) => t.deletedAt.isNotNull())
        ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
      .watch();

  Future<void> insertBrainDump(BrainDumpsCompanion entry) => into(brainDumps).insert(entry);

  Future<void> updateBrainDump(String id, BrainDumpsCompanion entry) =>
      (update(brainDumps)..where((t) => t.id.equals(id))).write(entry);

  Future<void> markAsReviewed(String id) =>
      (update(brainDumps)..where((t) => t.id.equals(id))).write(const BrainDumpsCompanion(isReviewed: Value(true)));

  Future<void> softDelete(String id) =>
      (update(brainDumps)..where((t) => t.id.equals(id))).write(BrainDumpsCompanion(deletedAt: Value(DateTime.now())));

  Future<void> restore(String id) =>
      (update(brainDumps)..where((t) => t.id.equals(id))).write(const BrainDumpsCompanion(deletedAt: Value(null)));

  Future<void> hardDelete(String id) => (delete(brainDumps)..where((t) => t.id.equals(id))).go();
}
