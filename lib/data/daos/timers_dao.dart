import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/timers_table.dart';
import '../tables/tags_table.dart';
import '../tables/junction_tables.dart';

part 'timers_dao.g.dart';

class TimerWithTags {
  final TimerEntry timer;
  final List<Tag> tags;

  TimerWithTags({required this.timer, required this.tags});
}

@DriftAccessor(tables: [Timers, TimerTags, Tags])
class TimersDao extends DatabaseAccessor<AppDatabase> with _$TimersDaoMixin {
  TimersDao(super.db);

  Stream<List<TimerEntry>> watchAll() => (select(timers)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
      .watch();

  Stream<List<TimerWithTags>> watchAllWithTags() {
    return watchAll().asyncMap((timerList) async {
      final List<TimerWithTags> results = [];
      for (final timer in timerList) {
        final tags = await (select(db.tags).join([
          innerJoin(db.timerTags, db.timerTags.tagId.equalsExp(db.tags.id)),
        ])..where(db.timerTags.timerId.equals(timer.id)))
            .map((row) => row.readTable(db.tags))
            .get();
        results.add(TimerWithTags(timer: timer, tags: tags));
      }
      return results;
    });
  }

  Future<void> upsert(TimersCompanion entry) {
    return into(timers).insertOnConflictUpdate(
      entry.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> softDelete(String id) =>
      (update(timers)..where((t) => t.id.equals(id)))
          .write(TimersCompanion(deletedAt: Value(DateTime.now())));

  Future<void> markCancelled(String id) =>
      (update(timers)..where((t) => t.id.equals(id)))
          .write(const TimersCompanion(isCancelled: Value(true)));
}
