// presentation/providers/sync_provider.dart
//
// Wires the WebDavSyncEngine together: settings -> WebDAV client,
// real DAOs -> SyncSources adapters -> engine. Also exposes a simple
// SyncController for triggering push/pull from the UI with loading
// state.
//
// The *Adapter classes below show the pattern for bridging your real
// Drift DAOs to the SyncableXSource interfaces. They're written against
// plausible method names from your schema (TodosDao, TasksDao,
// TrackersDao, RemindersDao) — rename to match your actual DAO API.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/sync/parsed_models.dart';
import '../../domain/sync/sync_transport.dart';
import '../../data/sync/webdav/webdav_client.dart';
import '../../data/sync/webdav/webdav_sync_engine.dart';
import '../../domain/sync/synced_dao_contacts.dart';
import 'sync_settings_provider.dart';

// ---------------------------------------------------------------------
// DAO adapters — bridge real Drift DAOs to the sync engine's contracts.
// Each method here is typically a few lines: fetch the Drift row(s),
// map field names across, done.
// ---------------------------------------------------------------------

class TodosSyncAdapter implements SyncableTodosSource {
  // final TodosDao dao;
  // TodosSyncAdapter(this.dao);

  @override
  Future<List<ParsedTodo>> findAllForPush() async {
    // final rows = await dao.findAll(includeDeleted: false);
    // return rows.map((r) => ParsedTodo(
    //   id: r.id,
    //   title: r.title,
    //   completed: r.completed,
    //   dueAt: r.nextDueAt,
    //   priority: _toParsedPriority(r.priority),
    //   tags: r.tags, // however tags are joined in for you today
    //   updatedAt: r.updatedAt,
    // )).toList();
    throw UnimplementedError('Wire up to TodosDao');
  }

  @override
  Future<ParsedTodo?> findById(String id) async {
    // final r = await dao.findById(id);
    // if (r == null) return null;
    // return ParsedTodo(...);
    throw UnimplementedError('Wire up to TodosDao');
  }

  @override
  Future<void> upsertFromRemote(ParsedTodo remote) async {
    // await dao.upsert(TodosCompanion(
    //   id: Value(remote.id),
    //   title: Value(remote.title),
    //   completed: Value(remote.completed),
    //   nextDueAt: Value(remote.dueAt),
    //   priority: Value(_fromParsedPriority(remote.priority)),
    //   updatedAt: Value(remote.updatedAt),
    //   syncedAt: Value(DateTime.now()),
    // ));
    // await dao.replaceTags(remote.id, remote.tags);
    throw UnimplementedError('Wire up to TodosDao');
  }
}

class TasksSyncAdapter implements SyncableTasksSource {
  // final TasksDao dao;
  // TasksSyncAdapter(this.dao);

  @override
  Future<List<ParsedTask>> findAllForPush() async {
    // final rows = await dao.findAll(includeDeleted: false);
    // final result = <ParsedTask>[];
    // for (final r in rows) {
    //   final logs = await dao.logsFor(r.id);
    //   result.add(ParsedTask(
    //     id: r.id,
    //     title: r.title,
    //     displayOrder: r.displayOrder,
    //     recurrence: r.recurrenceRule, // or however it's stringified
    //     tags: r.tags,
    //     reminders: await /* remindersAdapter */ null,
    //     updatedAt: r.updatedAt,
    //     logs: logs.map((l) => ParsedTaskLog(
    //       date: l.occurredOn,
    //       status: _toParsedStatus(l.status),
    //       note: l.note,
    //       skipReason: l.skipReason,
    //     )).toList(),
    //   ));
    // }
    // return result;
    throw UnimplementedError('Wire up to TasksDao');
  }

  @override
  Future<ParsedTask?> findById(String id) async {
    throw UnimplementedError('Wire up to TasksDao');
  }

  @override
  Future<void> upsertFromRemote(ParsedTask remote) async {
    // await dao.upsert(TasksCompanion(
    //   id: Value(remote.id),
    //   title: Value(remote.title),
    //   displayOrder: Value(remote.displayOrder),
    //   recurrenceRule: Value(remote.recurrence),
    //   updatedAt: Value(remote.updatedAt),
    //   syncedAt: Value(DateTime.now()),
    // ));
    // await dao.replaceTags(remote.id, remote.tags);
    // await dao.replaceLogsForTask(remote.id, remote.logs.map((l) =>
    //   TaskLogsCompanion.insert(
    //     taskId: remote.id,
    //     occurredOn: l.date,
    //     status: _fromParsedStatus(l.status),
    //     note: Value(l.note),
    //     skipReason: Value(l.skipReason),
    //   ),
    // ).toList());
    throw UnimplementedError('Wire up to TasksDao');
  }
}

class TrackersSyncAdapter implements SyncableTrackersSource {
  // final TrackersDao dao;
  // TrackersSyncAdapter(this.dao);

  @override
  Future<List<ParsedTracker>> findAllForPush() async {
    // final rows = await dao.findAll(includeDeleted: false);
    // final result = <ParsedTracker>[];
    // for (final r in rows) {
    //   final logs = await dao.logsFor(r.id);
    //   result.add(ParsedTracker(
    //     id: r.id,
    //     name: r.title,
    //     displayOrder: r.displayOrder,
    //     valueType: r.valueType == 'int'
    //         ? ParsedValueType.int : ParsedValueType.float,
    //     unit: r.unit,
    //     goalDirection: r.goalDirection == 'up'
    //         ? ParsedGoalDirection.up : ParsedGoalDirection.down,
    //     tags: r.tags,
    //     reminders: const [], // filled by RemindersSyncAdapter at merge time
    //     updatedAt: r.updatedAt,
    //     logs: logs.map((l) => ParsedTrackerLog(
    //       loggedAt: l.loggedAt,
    //       value: l.value,
    //     )).toList(),
    //   ));
    // }
    // return result;
    throw UnimplementedError('Wire up to TrackersDao');
  }

  @override
  Future<ParsedTracker?> findById(String id) async {
    throw UnimplementedError('Wire up to TrackersDao');
  }

  @override
  Future<void> upsertFromRemote(ParsedTracker remote) async {
    // await dao.upsert(TrackersCompanion(
    //   id: Value(remote.id),
    //   title: Value(remote.name),
    //   displayOrder: Value(remote.displayOrder),
    //   valueType: Value(remote.valueType.name),
    //   unit: Value(remote.unit),
    //   goalDirection: Value(remote.goalDirection.name),
    //   updatedAt: Value(remote.updatedAt),
    //   syncedAt: Value(DateTime.now()),
    // ));
    // await dao.replaceTags(remote.id, remote.tags);
    // await dao.upsertLogsByTimestamp(remote.id, remote.logs.map((l) =>
    //   TrackerLogsCompanion.insert(
    //     trackerId: remote.id,
    //     loggedAt: l.loggedAt,
    //     value: l.value,
    //   ),
    // ).toList());
    throw UnimplementedError('Wire up to TrackersDao');
  }
}

class RemindersSyncAdapter implements SyncableRemindersSource {
  // final RemindersDao dao;
  // RemindersSyncAdapter(this.dao);

  @override
  Future<List<String>> timesForTask(String taskId) async {
    throw UnimplementedError('Wire up to RemindersDao');
  }

  @override
  Future<List<String>> timesForTracker(String trackerId) async {
    throw UnimplementedError('Wire up to RemindersDao');
  }

  @override
  Future<List<String>> timesForTodo(String todoId) async {
    throw UnimplementedError('Wire up to RemindersDao');
  }

  @override
  Future<void> replaceTimesForTask(String taskId, List<String> times) async {
    // await dao.deleteAllForTask(taskId);
    // for (final t in times) {
    //   await dao.insert(RemindersCompanion.insert(
    //     taskId: Value(taskId),
    //     time: t,
    //   ));
    // }
    throw UnimplementedError('Wire up to RemindersDao');
  }

  @override
  Future<void> replaceTimesForTracker(
      String trackerId, List<String> times) async {
    throw UnimplementedError('Wire up to RemindersDao');
  }

  @override
  Future<void> replaceTimesForTodo(String todoId, List<String> times) async {
    throw UnimplementedError('Wire up to RemindersDao');
  }
}

// ---------------------------------------------------------------------
// Riverpod wiring
// ---------------------------------------------------------------------

final syncSourcesProvider = Provider<SyncSources>((ref) {
  return SyncSources(
    todos: TodosSyncAdapter(/* ref.watch(todosDaoProvider) */),
    tasks: TasksSyncAdapter(/* ref.watch(tasksDaoProvider) */),
    trackers: TrackersSyncAdapter(/* ref.watch(trackersDaoProvider) */),
    reminders: RemindersSyncAdapter(/* ref.watch(remindersDaoProvider) */),
  );
});

final syncEngineProvider = Provider<SyncTransport>((ref) {
  final settings = ref.watch(syncSettingsProvider);

  if (!settings.isConfigured) {
    return const NoOpSyncEngine();
  }

  final client = YatttaWebDavClient(
    url: settings.webdavUrl,
    username: settings.webdavUser,
    password: settings.webdavPassword,
  );

  ref.onDispose(client.dispose);

  return WebDavSyncEngine(
    client: client,
    sources: ref.watch(syncSourcesProvider),
    onProgress: (step) {
      // Wire to a simple status string provider if you want a
      // "Syncing: pushing tasks..." indicator in the UI.
    },
  );
});

enum SyncStatus { idle, syncing, error }

class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  const SyncState({this.status = SyncStatus.idle, this.errorMessage});
}

class SyncController extends StateNotifier<SyncState> {
  final Ref _ref;
  SyncController(this._ref) : super(const SyncState());

  Future<void> syncNow() async {
    state = const SyncState(status: SyncStatus.syncing);
    try {
      final engine = _ref.read(syncEngineProvider);
      // Pull first so local edits made since the last sync always win
      // on conflict (their updated_at will be newer than anything
      // just pulled), then push so the remote reflects local state.
      await engine.pull();
      await engine.push();
      await _ref.read(syncSettingsProvider.notifier).markSynced();
      state = const SyncState(status: SyncStatus.idle);
    } catch (e) {
      state = SyncState(status: SyncStatus.error, errorMessage: e.toString());
    }
  }
}

final syncControllerProvider =
StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref);
});
