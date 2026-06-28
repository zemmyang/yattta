import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/trackers_table.dart';
import '../tables/tracker_logs_table.dart';
import '../tables/tags_table.dart';
import '../tables/junction_tables.dart';

part 'trackers_dao.g.dart';

class TrackerWithTags {
  final Tracker tracker;
  final List<Tag> tags;

  TrackerWithTags({required this.tracker, required this.tags});
}

@DriftAccessor(tables: [Trackers, TrackerLogs, TrackerTags, Tags])
class TrackersDao extends DatabaseAccessor<AppDatabase>
    with _$TrackersDaoMixin {
  TrackersDao(super.db);

  // Watch all non-deleted trackers
  Stream<List<Tracker>> watchAll() => (select(trackers)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.asc(t.title)]))
      .watch();

  // Watch all deleted trackers
  Stream<List<Tracker>> watchDeleted() => (select(trackers)
    ..where((t) => t.deletedAt.isNotNull())
    ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
      .watch();

  Stream<List<TrackerWithTags>> watchAllWithTags() {
    final trackersStream = watchAll();
    return trackersStream.asyncMap((trackerList) async {
      final List<TrackerWithTags> results = [];
      for (final tracker in trackerList) {
        final tags = await (select(db.tags).join([
          innerJoin(db.trackerTags, db.trackerTags.tagId.equalsExp(db.tags.id)),
        ])..where(db.trackerTags.trackerId.equals(tracker.id)))
            .map((row) => row.readTable(db.tags))
            .get();
        results.add(TrackerWithTags(tracker: tracker, tags: tags));
      }
      return results;
    });
  }

  // Get logs for a tracker, most recent first
  Future<List<TrackerLog>> getLogsForTracker(String trackerId) =>
      (select(trackerLogs)
        ..where((l) => l.trackerId.equals(trackerId))
        ..orderBy([(l) => OrderingTerm.desc(l.loggedAt)]))
          .get();

  // Watch logs for a tracker
  Stream<List<TrackerLog>> watchLogsForTracker(String trackerId) =>
      (select(trackerLogs)
        ..where((l) => l.trackerId.equals(trackerId))
        ..orderBy([(l) => OrderingTerm.asc(l.loggedAt)]))
          .watch();

  // Watch logs within a date range (useful for charting)
  Stream<List<TrackerLog>> watchLogsInRange(
      String trackerId,
      DateTime from,
      DateTime to,
      ) =>
      (select(trackerLogs)
        ..where((l) =>
        l.trackerId.equals(trackerId) &
        l.loggedAt.isBetweenValues(from, to)))
          .watch();

  Future<void> upsert(TrackersCompanion entry) =>
      into(trackers).insertOnConflictUpdate(
        entry.copyWith(updatedAt: Value(DateTime.now())),
      );

  Future<void> addLog(TrackerLogsCompanion entry) =>
      into(trackerLogs).insert(entry);

  Future<void> updateLog(TrackerLogsCompanion entry) =>
      (update(trackerLogs)..where((l) => l.id.equals(entry.id.value)))
          .write(entry.copyWith(updatedAt: Value(DateTime.now())));

  Future<void> deleteLog(String logId) =>
      (delete(trackerLogs)..where((l) => l.id.equals(logId))).go();

  Future<void> softDelete(String id) =>
      (update(trackers)..where((t) => t.id.equals(id)))
          .write(TrackersCompanion(deletedAt: Value(DateTime.now())));

  Future<void> restore(String id) =>
      (update(trackers)..where((t) => t.id.equals(id)))
          .write(const TrackersCompanion(deletedAt: Value(null)));

  Future<void> hardDelete(String id) =>
      (delete(trackers)..where((t) => t.id.equals(id))).go();
}