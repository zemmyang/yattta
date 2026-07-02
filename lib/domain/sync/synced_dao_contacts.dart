// domain/sync/sync_dao_contracts.dart
//
// The sync engine doesn't talk to TodosDao / TasksDao / TrackersDao /
// RemindersDao directly, because their exact method signatures are an
// implementation detail that will keep evolving. Instead it depends on
// these small interfaces. Implement them as thin adapters/extensions on
// top of your real DAOs — usually a one-to-one method mapping, a few
// lines each. This keeps the sync engine stable even as the DB layer
// changes.

import 'parsed_models.dart';

/// What the sync engine needs from the todos table.
abstract class SyncableTodosSource {
  /// All non-deleted todos, newest metadata included.
  Future<List<ParsedTodo>> findAllForPush();

  /// Single row lookup by id, or null if not present / soft-deleted.
  Future<ParsedTodo?> findById(String id);

  /// Insert or update based on remote data. Implementer decides
  /// whether to touch `synced_at`.
  Future<void> upsertFromRemote(ParsedTodo remote);
}

/// What the sync engine needs from the tasks (habits) + task_logs tables.
abstract class SyncableTasksSource {
  Future<List<ParsedTask>> findAllForPush();

  Future<ParsedTask?> findById(String id);

  /// Upsert the task row AND replace/merge its logs. Implementer's
  /// choice whether to fully replace logs or merge by date — full
  /// replace is simplest and matches "remote file is the truth for
  /// this task" semantics already used elsewhere in sync.
  Future<void> upsertFromRemote(ParsedTask remote);
}

/// What the sync engine needs from the trackers + tracker_logs tables.
abstract class SyncableTrackersSource {
  Future<List<ParsedTracker>> findAllForPush();

  Future<ParsedTracker?> findById(String id);

  Future<void> upsertFromRemote(ParsedTracker remote);
}

/// Reminders are keyed by exactly one of todo_id / task_id / tracker_id
/// per the CHECK constraint. The sync engine only ever pushes/pulls
/// reminders as plain "HH:mm" strings embedded in the owning entity's
/// frontmatter — this interface reconciles those strings against actual
/// reminder rows.
abstract class SyncableRemindersSource {
  Future<List<String>> timesForTask(String taskId);
  Future<List<String>> timesForTracker(String trackerId);
  Future<List<String>> timesForTodo(String todoId);

  Future<void> replaceTimesForTask(String taskId, List<String> times);
  Future<void> replaceTimesForTracker(String trackerId, List<String> times);
  Future<void> replaceTimesForTodo(String todoId, List<String> times);
}

/// Bundles all four sources so the engine takes one object instead of
/// four constructor params.
class SyncSources {
  final SyncableTodosSource todos;
  final SyncableTasksSource tasks;
  final SyncableTrackersSource trackers;
  final SyncableRemindersSource reminders;

  SyncSources({
    required this.todos,
    required this.tasks,
    required this.trackers,
    required this.reminders,
  });
}
