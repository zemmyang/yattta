// data/sync/webdav/webdav_sync_engine.dart
//
// Implements SyncTransport using WebDAV markdown files as the medium.
// Drift remains the source of truth on-device; this engine only moves
// data in and out via the SyncSources adapters.
//
// Conflict rule throughout: last-write-wins on `updated_at`. Whichever
// side has the newer timestamp overwrites the other. This is the same
// rule already used for trackers/tasks reminders.

import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../domain/sync/parsed_models.dart';
import '../../../domain/sync/sync_transport.dart';
import '../../../domain/sync/synced_dao_contacts.dart';
import '../serializers/braindump_file_serializer.dart';
import '../serializers/settings_file_serializer.dart';
import '../serializers/task_file_serializer.dart';
import '../serializers/todo_file_serializer.dart';
import '../serializers/tracker_file_serializer.dart';
import '../serializers/yaml_write_utils.dart';
import 'webdav_client.dart';

class WebDavSyncEngine implements SyncTransport {
  final YatttaWebDavClient client;
  final SyncSources sources;
  final Map<String, String> _etags = {};
  final Map<String, Uint8List> _remoteContent = {};

  /// Called after each push/pull step so the UI can show progress.
  /// Optional — pass null to ignore.
  final void Function(String step)? onProgress;

  WebDavSyncEngine({
    required this.client,
    required this.sources,
    this.onProgress,
  });

  void _report(String step) => onProgress?.call(step);

  @override
  Future<void> push() async {
    _report('Ensuring server folders exist');
    await client.ensureYatttaFolders();

    final steps = [
      ('Pushing todos...', _pushTodos),
      ('Pushing tasks...', _pushTasks),
      ('Pushing trackers...', _pushTrackers),
      ('Pushing braindumps...', _pushBraindumps),
      ('Pushing settings...', _pushSettings),
    ];

    for (final step in steps) {
      try {
        _report(step.$1);
        await step.$2();
      } catch (e) {
        if (kDebugMode) {
          print('WebDAV Sync: Step ${step.$1} failed: $e');
        }
        // We don't rethrow here to allow other steps to complete.
        // The SyncController will still see the last error if we rethrow at the end
        // but for now let's just log and continue.
      }
    }
  }

  @override
  Future<void> pull() async {
    // If the base folder doesn't exist yet, there's nothing to pull.
    // This is expected on the very first sync from a new device.
    if (!await client.exists('yattta', isDirectory: true)) {
      _report('Server empty, skipping pull');
      return;
    }

    final steps = [
      ('Pulling todos...', _pullTodos),
      ('Pulling tasks...', _pullTasks),
      ('Pulling trackers...', _pullTrackers),
      ('Pulling braindumps...', _pullBraindumps),
      ('Pulling settings...', _pullSettings),
    ];

    for (final step in steps) {
      try {
        _report(step.$1);
        await step.$2();
      } catch (e) {
        if (kDebugMode) {
          print('WebDAV Sync: Step ${step.$1} failed: $e');
        }
        // Continue to next pull step
      }
    }
  }

  // ---------------------------------------------------------------------
  // Todos — grouped by priority under /yattta/todos/
  // ---------------------------------------------------------------------

  Future<void> _pushTodos() async {
    final todos = await sources.todos.findAllForPush();

    // Group by priority
    final grouped = <ParsedPriority, List<ParsedTodo>>{};
    for (final t in todos) {
      grouped.putIfAbsent(t.priority, () => []).add(t);
    }

    // Write one file per priority
    for (final priority in ParsedPriority.values) {
      final list = grouped[priority] ?? [];
      final content = TodoFileSerializer.serialize(list);
      final filename = '${priority.name}.md';
      await _safeWrite('yattta/todos/$filename', _bytes(content));
    }
  }

  Future<void> _pullTodos() async {
    // 1. Pull from the new folder structure
    final files = await client.list('yattta/todos');
    final mdFiles = files.where(
      (f) => !f.isDirectory && f.name.endsWith('.md'),
    );

    for (final file in mdFiles) {
      final result = await client.read(file.path);
      if (result == null) continue;

      _remoteContent[file.path] = result.bytes;
      if (result.etag != null) {
        _etags[file.path] = result.etag!;
      }

      final remoteTodos = TodoFileSerializer.parse(utf8.decode(result.bytes));
      for (final remote in remoteTodos) {
        final local = await sources.todos.findById(remote.id);
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          await sources.todos.upsertFromRemote(remote);
        }
      }
    }

    // 2. Backward compatibility: pull from legacy single-file format
    final legacy = await client.read('yattta/todos.md');
    if (legacy != null) {
      _remoteContent['yattta/todos.md'] = legacy.bytes;
      if (legacy.etag != null) {
        _etags['yattta/todos.md'] = legacy.etag!;
      }

      final remoteTodos = TodoFileSerializer.parse(utf8.decode(legacy.bytes));
      for (final remote in remoteTodos) {
        final local = await sources.todos.findById(remote.id);
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          await sources.todos.upsertFromRemote(remote);
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // Tasks — one file per task under /yattta/tasks/
  // ---------------------------------------------------------------------

  Future<void> _pushTasks() async {
    final tasks = await sources.tasks.findAllForPush();
    final sorted = [...tasks]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    for (final task in sorted) {
      final content = TaskFileSerializer.serialize(task);
      final slug = slugify(task.title);
      final shortId = task.id.substring(0, 8);
      await _safeWrite('yattta/tasks/$slug-$shortId.md', _bytes(content));
    }
  }

  Future<void> _pullTasks() async {
    final files = await client.list('yattta/tasks');
    final mdFiles = files.where(
          (f) => !f.isDirectory && f.name.endsWith('.md'),
    );

    for (final file in mdFiles) {
      final result = await client.read(file.path);
      if (result == null) continue;

      _remoteContent[file.path] = result.bytes;
      if (result.etag != null) {
        _etags[file.path] = result.etag!;
      }

      final ParsedTask remote;
      try {
        remote = TaskFileSerializer.parse(utf8.decode(result.bytes));
      } catch (_) {
        // Malformed file — skip it.
        continue;
      }

      final local = await sources.tasks.findById(remote.id);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await sources.tasks.upsertFromRemote(remote);
        await sources.reminders.replaceTimesForTask(
          remote.id,
          remote.reminders,
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Trackers — one file per tracker under /yattta/trackers/
  // ---------------------------------------------------------------------

  Future<void> _pushTrackers() async {
    final trackers = await sources.trackers.findAllForPush();
    // final sorted = [...trackers]
    //   ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    for (final tracker in trackers) {
      final content = TrackerFileSerializer.serialize(tracker);
      final slug = slugify(tracker.name);
      final shortId = tracker.id.substring(0, 8);
      await _safeWrite('yattta/trackers/$slug-$shortId.md', _bytes(content));
    }
  }

  Future<void> _pullTrackers() async {
    final files = await client.list('yattta/trackers');
    final mdFiles = files.where(
          (f) => !f.isDirectory && f.name.endsWith('.md'),
    );

    for (final file in mdFiles) {
      final result = await client.read(file.path);
      if (result == null) continue;

      _remoteContent[file.path] = result.bytes;
      if (result.etag != null) {
        _etags[file.path] = result.etag!;
      }

      final ParsedTracker remote;
      try {
        remote = TrackerFileSerializer.parse(utf8.decode(result.bytes));
      } catch (_) {
        continue;
      }

      final local = await sources.trackers.findById(remote.id);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await sources.trackers.upsertFromRemote(remote);
        await sources.reminders.replaceTimesForTracker(
          remote.id,
          remote.reminders,
        );
      }
    }
  }

  Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

  // ---------------------------------------------------------------------
  // Brain Dumps — one file per dump under /yattta/braindumps/
  // ---------------------------------------------------------------------

  Future<void> _pushBraindumps() async {
    final dumps = await sources.brainDumps.findAllForPush();
    
    for (final d in dumps) {
      final content = BraindumpFileSerializer.serializeSingle(d);
      
      // Filename: YYYYMMDD_HHMMSS-shortId.md
      final ts = d.createdAt.toIso8601String()
          .replaceAll(RegExp(r'[:\-]'), '')
          .split('.')[0]
          .replaceFirst('T', '_');
      final shortId = d.id.substring(0, 8);
      
      await _safeWrite('yattta/braindumps/$ts-$shortId.md', _bytes(content));
    }
  }

  Future<void> _pullBraindumps() async {
    // 1. Pull from the new folder structure
    final files = await client.list('yattta/braindumps');
    final mdFiles = files.where(
      (f) => !f.isDirectory && f.name.endsWith('.md'),
    );

    for (final file in mdFiles) {
      final result = await client.read(file.path);
      if (result == null) continue;

      _remoteContent[file.path] = result.bytes;
      if (result.etag != null) {
        _etags[file.path] = result.etag!;
      }

      final ParsedBrainDump remote;
      try {
        remote = BraindumpFileSerializer.parseSingle(utf8.decode(result.bytes));
      } catch (_) {
        continue;
      }

      final local = await sources.brainDumps.findById(remote.id);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await sources.brainDumps.upsertFromRemote(remote);
      }
    }

    // 2. Backward compatibility: pull from the old single-file format if it exists
    final legacy = await client.read('yattta/braindumps.md');
    if (legacy != null) {
      _remoteContent['yattta/braindumps.md'] = legacy.bytes;
      if (legacy.etag != null) {
        _etags['yattta/braindumps.md'] = legacy.etag!;
      }

      final remoteDumps = BraindumpFileSerializer.parse(utf8.decode(legacy.bytes));
      for (final remote in remoteDumps) {
        final local = await sources.brainDumps.findById(remote.id);
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          await sources.brainDumps.upsertFromRemote(remote);
        }
      }
      
      // Optional: we could delete the legacy file here after successful migration, 
      // but keeping it is safer until we're sure the user's other devices have synced.
    }
  }

  // ---------------------------------------------------------------------
  // Settings — single file
  // ---------------------------------------------------------------------

  Future<void> _pushSettings() async {
    final settings = await sources.settings.findAllForPush();
    final content = SettingsFileSerializer.serialize(settings);
    await _safeWrite('yattta/settings.yaml', _bytes(content));
  }

  Future<void> _pullSettings() async {
    final result = await client.read('yattta/settings.yaml');
    if (result == null) return;
    
    _remoteContent['yattta/settings.yaml'] = result.bytes;
    if (result.etag != null) {
      _etags['yattta/settings.yaml'] = result.etag!;
    }

    final remoteSettings = SettingsFileSerializer.parse(utf8.decode(result.bytes));

    for (final remote in remoteSettings) {
      final local = await sources.settings.findByKey(remote.key);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await sources.settings.upsertFromRemote(remote);
      }
    }
  }

  // ---------------------------------------------------------------------
  // Internal write wrapper
  // ---------------------------------------------------------------------

  /// Writes to WebDAV only if the content changed, using ETags for concurrency.
  Future<void> _safeWrite(String path, Uint8List bytes) async {
    final old = _remoteContent[path];
    if (old != null && _listEquals(old, bytes)) {
      return;
    }

    final etag = _etags[path];
    await client.write(path, bytes, ifMatch: etag);
    
    _remoteContent[path] = bytes;
    // We don't know the NEW etag yet (unless we do another PROPFIND),
    // so we clear the old one. The next pull will refresh it.
    _etags.remove(path);
  }

  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
