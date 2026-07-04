// presentation/providers/sync_provider.dart
//
// Wires the WebDavSyncEngine together: settings -> WebDAV client,
// real DAOs -> SyncSources adapters -> engine. Also exposes a simple
// SyncController for triggering push/pull from the UI with loading
// state.

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/daos/todos_dao.dart';
import '../../data/daos/tasks_dao.dart';
import '../../data/daos/trackers_dao.dart';
import '../../data/daos/reminders_dao.dart';
import '../../data/daos/tags_dao.dart';
import '../../data/daos/brain_dumps_dao.dart';
import '../../data/daos/settings_dao.dart';
import '../../data/converters/enum_converters.dart';
import 'database_providers.dart';

import '../../domain/sync/parsed_models.dart';
import '../../domain/sync/sync_transport.dart';
import '../../data/sync/webdav/webdav_client.dart';
import '../../data/sync/webdav/webdav_sync_engine.dart';
import '../../domain/sync/synced_dao_contacts.dart';
import '../../domain/models/recurrence_rule.dart';
import 'sync_settings_provider.dart';

// ---------------------------------------------------------------------
// DAO adapters — bridge real Drift DAOs to the sync engine's contracts.
// Each method here is typically a few lines: fetch the Drift row(s),
// map field names across, done.
// ---------------------------------------------------------------------

class TodosSyncAdapter implements SyncableTodosSource {
  final TodosDao dao;
  final TagsDao tagsDao;
  TodosSyncAdapter(this.dao, this.tagsDao);

  @override
  Future<List<ParsedTodo>> findAllForPush() async {
    final rows = await (dao.select(dao.todos)..where((t) => t.deletedAt.isNull())).get();
    final result = <ParsedTodo>[];
    for (final r in rows) {
      final tags = await tagsDao.getTagsForTodo(r.id);
      result.add(ParsedTodo(
        id: r.id,
        title: r.title,
        completed: r.status == TodoStatus.done,
        dueAt: r.dueAt,
        priority: _toParsedPriority(r.priority),
        tags: tags.map((t) => t.name).toList(),
        updatedAt: r.updatedAt,
      ));
    }
    return result;
  }

  @override
  Future<ParsedTodo?> findById(String id) async {
    final r = await (dao.select(dao.todos)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (r == null) return null;
    final tags = await tagsDao.getTagsForTodo(r.id);
    return ParsedTodo(
      id: r.id,
      title: r.title,
      completed: r.status == TodoStatus.done,
      dueAt: r.dueAt,
      priority: _toParsedPriority(r.priority),
      tags: tags.map((t) => t.name).toList(),
      updatedAt: r.updatedAt,
    );
  }

  @override
  Future<void> upsertFromRemote(ParsedTodo remote) async {
    await dao.upsert(TodosCompanion(
      id: Value(remote.id),
      title: Value(remote.title),
      status: Value(remote.completed ? TodoStatus.done : TodoStatus.pending),
      dueAt: Value(remote.dueAt),
      priority: Value(_fromParsedPriority(remote.priority)),
      updatedAt: Value(remote.updatedAt),
    ));

    await tagsDao.detachAllFromTodo(remote.id);
    for (final tagName in remote.tags) {
      final tagId = await _getOrCreateTag(tagName);
      await tagsDao.attachToTodo(remote.id, tagId);
    }
  }

  Future<String> _getOrCreateTag(String name) async {
    final existing = await (tagsDao.select(tagsDao.tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;

    final id = name.toLowerCase().replaceAll(' ', '_');
    await tagsDao.upsert(TagsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
    return id;
  }
}

class TasksSyncAdapter implements SyncableTasksSource {
  final TasksDao dao;
  final TagsDao tagsDao;
  final RemindersDao remindersDao;
  TasksSyncAdapter(this.dao, this.tagsDao, this.remindersDao);

  @override
  Future<List<ParsedTask>> findAllForPush() async {
    final rows = await (dao.select(dao.tasks)..where((t) => t.deletedAt.isNull())).get();
    final result = <ParsedTask>[];
    for (final r in rows) {
      final tags = await tagsDao.getTagsForTask(r.id);
      final logs = await dao.getLogsForTask(r.id);
      final reminders = await remindersDao.getForTask(r.id);

      result.add(ParsedTask(
        id: r.id,
        title: r.title,
        displayOrder: r.position,
        recurrence: r.recurrenceRule.toString(),
        tags: tags.map((t) => t.name).toList(),
        reminders: reminders.map((rem) => _formatTime(rem.remindAt)).toList(),
        updatedAt: r.updatedAt,
        logs: logs.map((l) => ParsedTaskLog(
          date: l.triggeredAt,
          status: _toParsedTaskLogStatus(l.status),
          note: l.notes,
          skipReason: l.skipReason,
        )).toList(),
      ));
    }
    return result;
  }

  @override
  Future<ParsedTask?> findById(String id) async {
    final r = await (dao.select(dao.tasks)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (r == null) return null;
    final tags = await tagsDao.getTagsForTask(r.id);
    final logs = await dao.getLogsForTask(r.id);
    final reminders = await remindersDao.getForTask(r.id);

    return ParsedTask(
      id: r.id,
      title: r.title,
      displayOrder: r.position,
      recurrence: r.recurrenceRule.toString(),
      tags: tags.map((t) => t.name).toList(),
      reminders: reminders.map((rem) => _formatTime(rem.remindAt)).toList(),
      updatedAt: r.updatedAt,
      logs: logs.map((l) => ParsedTaskLog(
        date: l.triggeredAt,
        status: _toParsedTaskLogStatus(l.status),
        note: l.notes,
        skipReason: l.skipReason,
      )).toList(),
    );
  }

  @override
  Future<void> upsertFromRemote(ParsedTask remote) async {
    // Parse recurrence string back to RecurrenceRule object
    // If parsing fails or is null, default to 'none'
    RecurrenceRule rrule = const RecurrenceRule(frequency: 'none');
    if (remote.recurrence != null && remote.recurrence != 'None') {
      // The serializer currently stores toString() which is not easily reversible
      // but the domain model expects frequency. For now, let's try to infer it.
      final lower = remote.recurrence!.toLowerCase();
      if (lower.contains('daily')) {
        rrule = const RecurrenceRule(frequency: 'daily');
      } else if (lower.contains('weekly')) {
        rrule = const RecurrenceRule(frequency: 'weekly');
      } else if (lower.contains('monthly')) {
        rrule = const RecurrenceRule(frequency: 'monthly');
      }
    }

    await dao.upsert(TasksCompanion(
      id: Value(remote.id),
      title: Value(remote.title),
      position: Value(remote.displayOrder),
      updatedAt: Value(remote.updatedAt),
      recurrenceRule: Value(rrule),
    ));

    await tagsDao.detachAllFromTask(remote.id);
    for (final tagName in remote.tags) {
      final tagId = await _getOrCreateTag(tagName);
      await tagsDao.attachToTask(remote.id, tagId);
    }

    final existingLogs = await dao.getLogsForTask(remote.id);
    for (final l in existingLogs) {
      await dao.deleteLog(l.id);
    }

    for (final l in remote.logs) {
      await dao.logOccurrence(TaskLogsCompanion(
        id: Value(remote.id + l.date.millisecondsSinceEpoch.toString()),
        taskId: Value(remote.id),
        triggeredAt: Value(l.date),
        status: Value(_fromParsedTaskLogStatus(l.status)),
        notes: Value(l.note),
        skipReason: Value(l.skipReason),
      ));
    }
  }

  Future<String> _getOrCreateTag(String name) async {
    final existing = await (tagsDao.select(tagsDao.tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;

    final id = name.toLowerCase().replaceAll(' ', '_');
    await tagsDao.upsert(TagsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
    return id;
  }
}

class TrackersSyncAdapter implements SyncableTrackersSource {
  final TrackersDao dao;
  final TagsDao tagsDao;
  final RemindersDao remindersDao;
  TrackersSyncAdapter(this.dao, this.tagsDao, this.remindersDao);

  @override
  Future<List<ParsedTracker>> findAllForPush() async {
    final rows = await (dao.select(dao.trackers)..where((t) => t.deletedAt.isNull())).get();
    final result = <ParsedTracker>[];
    for (final r in rows) {
      final tags = await tagsDao.getTagsForTracker(r.id);
      final logs = await dao.getLogsForTracker(r.id);
      final reminders = await remindersDao.getForTracker(r.id);

      result.add(ParsedTracker(
        id: r.id,
        name: r.title,
        displayOrder: r.position,
        valueType: r.valueType == TrackerValueType.integer ? ParsedValueType.int : ParsedValueType.float,
        unit: r.unit ?? '',
        goalDirection: r.direction == TrackerDirection.increasing ? ParsedGoalDirection.up : ParsedGoalDirection.down,
        tags: tags.map((t) => t.name).toList(),
        reminders: reminders.map((rem) => _formatTime(rem.remindAt)).toList(),
        updatedAt: r.updatedAt,
        logs: logs.map((l) => ParsedTrackerLog(
          loggedAt: l.loggedAt,
          value: l.value,
        )).toList(),
      ));
    }
    return result;
  }

  @override
  Future<ParsedTracker?> findById(String id) async {
    final r = await (dao.select(dao.trackers)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (r == null) return null;
    final tags = await tagsDao.getTagsForTracker(r.id);
    final logs = await dao.getLogsForTracker(r.id);
    final reminders = await remindersDao.getForTracker(r.id);

    return ParsedTracker(
      id: r.id,
      name: r.title,
      displayOrder: r.position,
      valueType: r.valueType == TrackerValueType.integer ? ParsedValueType.int : ParsedValueType.float,
      unit: r.unit ?? '',
      goalDirection: r.direction == TrackerDirection.increasing ? ParsedGoalDirection.up : ParsedGoalDirection.down,
      tags: tags.map((t) => t.name).toList(),
      reminders: reminders.map((rem) => _formatTime(rem.remindAt)).toList(),
      updatedAt: r.updatedAt,
      logs: logs.map((l) => ParsedTrackerLog(
        loggedAt: l.loggedAt,
        value: l.value,
      )).toList(),
    );
  }

  @override
  Future<void> upsertFromRemote(ParsedTracker remote) async {
    await dao.upsert(TrackersCompanion(
      id: Value(remote.id),
      title: Value(remote.name),
      position: Value(remote.displayOrder),
      valueType: Value(remote.valueType == ParsedValueType.int ? TrackerValueType.integer : TrackerValueType.double),
      unit: Value(remote.unit),
      direction: Value(remote.goalDirection == ParsedGoalDirection.up ? TrackerDirection.increasing : TrackerDirection.decreasing),
      updatedAt: Value(remote.updatedAt),
    ));

    await tagsDao.detachAllFromTracker(remote.id);
    for (final tagName in remote.tags) {
      final tagId = await _getOrCreateTag(tagName);
      await tagsDao.attachToTracker(remote.id, tagId);
    }

    final existingLogs = await dao.getLogsForTracker(remote.id);
    for (final l in existingLogs) {
      await dao.deleteLog(l.id);
    }

    for (final l in remote.logs) {
      await dao.addLog(TrackerLogsCompanion(
        id: Value(remote.id + l.loggedAt.millisecondsSinceEpoch.toString()),
        trackerId: Value(remote.id),
        loggedAt: Value(l.loggedAt),
        value: Value(l.value),
      ));
    }
  }

  Future<String> _getOrCreateTag(String name) async {
    final existing = await (tagsDao.select(tagsDao.tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;

    final id = name.toLowerCase().replaceAll(' ', '_');
    await tagsDao.upsert(TagsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
    return id;
  }
}

class BrainDumpsSyncAdapter implements SyncableBrainDumpsSource {
  final BrainDumpsDao dao;
  final TagsDao tagsDao;
  BrainDumpsSyncAdapter(this.dao, this.tagsDao);

  @override
  Future<List<ParsedBrainDump>> findAllForPush() async {
    final rows = await (dao.select(dao.brainDumps)..where((t) => t.deletedAt.isNull())).get();
    final result = <ParsedBrainDump>[];
    for (final r in rows) {
      final tags = await tagsDao.getTagsForBrainDump(r.id);
      result.add(ParsedBrainDump(
        id: r.id,
        note: r.note,
        isReviewed: r.isReviewed,
        tags: tags.map((t) => t.name).toList(),
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      ));
    }
    return result;
  }

  @override
  Future<ParsedBrainDump?> findById(String id) async {
    final r = await (dao.select(dao.brainDumps)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (r == null) return null;
    final tags = await tagsDao.getTagsForBrainDump(r.id);
    return ParsedBrainDump(
      id: r.id,
      note: r.note,
      isReviewed: r.isReviewed,
      tags: tags.map((t) => t.name).toList(),
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  @override
  Future<void> upsertFromRemote(ParsedBrainDump remote) async {
    // If row exists, update it. If not, insert it.
    final existing = await (dao.select(dao.brainDumps)..where((t) => t.id.equals(remote.id))).getSingleOrNull();
    if (existing != null) {
      await dao.updateBrainDump(remote.id, BrainDumpsCompanion(
        note: Value(remote.note),
        isReviewed: Value(remote.isReviewed),
        updatedAt: Value(remote.updatedAt),
        deletedAt: const Value(null),
      ));
    } else {
      await dao.insertBrainDump(BrainDumpsCompanion.insert(
        id: remote.id,
        note: remote.note,
        isReviewed: Value(remote.isReviewed),
        createdAt: Value(remote.createdAt),
        updatedAt: Value(remote.updatedAt),
      ));
    }

    await tagsDao.detachAllFromBrainDump(remote.id);
    for (final tagName in remote.tags) {
      final tagId = await _getOrCreateTag(tagName);
      await tagsDao.attachToBrainDump(remote.id, tagId);
    }
  }

  Future<String> _getOrCreateTag(String name) async {
    final existing = await (tagsDao.select(tagsDao.tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;

    final id = name.toLowerCase().replaceAll(' ', '_');
    await tagsDao.upsert(TagsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
    return id;
  }
}

class SettingsSyncAdapter implements SyncableSettingsSource {
  final SettingsDao dao;
  SettingsSyncAdapter(this.dao);

  @override
  Future<List<ParsedSetting>> findAllForPush() async {
    final rows = await dao.select(dao.settings).get();
    return rows.map((r) => ParsedSetting(
      key: r.key,
      value: r.value,
      updatedAt: r.updatedAt,
    )).toList();
  }

  @override
  Future<ParsedSetting?> findByKey(String key) async {
    final r = await (dao.select(dao.settings)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (r == null) return null;
    return ParsedSetting(
      key: r.key,
      value: r.value,
      updatedAt: r.updatedAt,
    );
  }

  @override
  Future<void> upsertFromRemote(ParsedSetting remote) async {
    // Skip WebDAV credentials to avoid circular dependency and security risks
    if (remote.key.startsWith('webDav')) return;
    
    await dao.setString(remote.key, remote.value);
    // dao.setString sets updatedAt to now, so we need a way to set it to remote.updatedAt if we want strict last-write-wins
    // Let's modify SettingsDao to accept an optional updatedAt or just use insertOnConflictUpdate directly here.
    await (dao.into(dao.settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: Value(remote.key),
        value: Value(remote.value),
        updatedAt: Value(remote.updatedAt),
      ),
    ));
  }
}

class RemindersSyncAdapter implements SyncableRemindersSource {
  final RemindersDao dao;
  RemindersSyncAdapter(this.dao);

  @override
  Future<List<String>> timesForTask(String taskId) async {
    final rems = await dao.getForTask(taskId);
    return rems.map((r) => _formatTime(r.remindAt)).toList();
  }

  @override
  Future<List<String>> timesForTracker(String trackerId) async {
    final rems = await dao.getForTracker(trackerId);
    return rems.map((r) => _formatTime(r.remindAt)).toList();
  }

  @override
  Future<List<String>> timesForTodo(String todoId) async {
    final rems = await dao.getForTodo(todoId);
    return rems.map((r) => _formatTime(r.remindAt)).toList();
  }

  @override
  Future<void> replaceTimesForTask(String taskId, List<String> times) async {
    await dao.deleteAllForTask(taskId);
    for (final t in times) {
      final time = _parseTime(t);
      await dao.upsert(RemindersCompanion(
        id: Value(taskId + t),
        taskId: Value(taskId),
        remindAt: Value(time),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isActive: const Value(true),
        isSent: const Value(false),
      ));
    }
  }

  @override
  Future<void> replaceTimesForTracker(
      String trackerId, List<String> times) async {
    final existing = await dao.getForTracker(trackerId);
    for (final e in existing) {
      await dao.softDelete(e.id);
    }
    for (final t in times) {
      final time = _parseTime(t);
      await dao.upsert(RemindersCompanion(
        id: Value(trackerId + t),
        trackerId: Value(trackerId),
        remindAt: Value(time),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isActive: const Value(true),
        isSent: const Value(false),
      ));
    }
  }

  @override
  Future<void> replaceTimesForTodo(String todoId, List<String> times) async {
    final existing = await dao.getForTodo(todoId);
    for (final e in existing) {
      await dao.softDelete(e.id);
    }
    for (final t in times) {
      final time = _parseTime(t);
      await dao.upsert(RemindersCompanion(
        id: Value(todoId + t),
        todoId: Value(todoId),
        remindAt: Value(time),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isActive: const Value(true),
        isSent: const Value(false),
      ));
    }
  }
}

// ---------------------------------------------------------------------
// Riverpod wiring
// ---------------------------------------------------------------------

final syncSourcesProvider = Provider<SyncSources>((ref) {
  return SyncSources(
    todos: TodosSyncAdapter(
      ref.watch(todosDaoProvider),
      ref.watch(tagsDaoProvider),
    ),
    tasks: TasksSyncAdapter(
      ref.watch(tasksDaoProvider),
      ref.watch(tagsDaoProvider),
      ref.watch(remindersDaoProvider),
    ),
    trackers: TrackersSyncAdapter(
      ref.watch(trackersDaoProvider),
      ref.watch(tagsDaoProvider),
      ref.watch(remindersDaoProvider),
    ),
    reminders: RemindersSyncAdapter(ref.watch(remindersDaoProvider)),
    brainDumps: BrainDumpsSyncAdapter(
      ref.watch(brainDumpsDaoProvider),
      ref.watch(tagsDaoProvider),
    ),
    settings: SettingsSyncAdapter(ref.watch(settingsDaoProvider)),
  );
});

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------

ParsedPriority _toParsedPriority(int? p) {
  if (p == null) return ParsedPriority.normal;
  if (p <= 1) return ParsedPriority.low;
  if (p >= 3) return ParsedPriority.high;
  return ParsedPriority.normal;
}

int _fromParsedPriority(ParsedPriority p) {
  return switch (p) {
    ParsedPriority.low => 1,
    ParsedPriority.normal => 2,
    ParsedPriority.high => 3,
  };
}

ParsedLogStatus _toParsedTaskLogStatus(TaskLogStatus s) {
  return switch (s) {
    TaskLogStatus.done => ParsedLogStatus.done,
    TaskLogStatus.notDone => ParsedLogStatus.notDone,
    TaskLogStatus.skipped => ParsedLogStatus.skipped,
  };
}

TaskLogStatus _fromParsedTaskLogStatus(ParsedLogStatus s) {
  return switch (s) {
    ParsedLogStatus.done => TaskLogStatus.done,
    ParsedLogStatus.notDone => TaskLogStatus.notDone,
    ParsedLogStatus.skipped => TaskLogStatus.skipped,
  };
}

String _formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime _parseTime(String t) {
  final parts = t.split(':');
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

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
      ref.read(syncProgressProvider.notifier).state = step;
    },
  );
});

final syncProgressProvider = StateProvider<String?>((ref) => null);

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
    if (state.status == SyncStatus.syncing) return;

    state = const SyncState(status: SyncStatus.syncing);
    try {
      final engine = _ref.read(syncEngineProvider);
      
      if (engine is WebDavSyncEngine) {
        if (kDebugMode) print('WebDAV Sync: Checking server availability...');
        await engine.client.ping();
      }

      if (kDebugMode) print('Starting WebDAV Sync: Pulling...');
      await engine.pull();
      
      if (kDebugMode) print('WebDAV Sync: Pushing...');
      await engine.push();
      
      await _ref.read(syncSettingsProvider.notifier).markSynced();
      
      if (kDebugMode) print('WebDAV Sync: Completed successfully');
      state = const SyncState(status: SyncStatus.idle);
      _ref.read(syncProgressProvider.notifier).state = null;
    } catch (e, stack) {
      if (kDebugMode) {
        print('WebDAV Sync Error: $e');
        print(stack);
      }

      String msg = e.toString();
      if (e is YatttaWebDavException) {
        msg = e.friendlyMessage;
      }

      state = SyncState(status: SyncStatus.error, errorMessage: msg);
      _ref.read(syncProgressProvider.notifier).state = null;
    }
  }
}

final syncControllerProvider =
StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref);
});
