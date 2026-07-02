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
import 'dart:typed_data';

import '../../../domain/sync/parsed_models.dart';
import '../../../domain/sync/sync_transport.dart';
import '../../../domain/sync/synced_dao_contacts.dart';
import '../serializers/task_file_serializer.dart';
import '../serializers/todo_file_serializer.dart';
import '../serializers/tracker_file_serializer.dart';
import '../serializers/yaml_write_utils.dart';
import 'webdav_client.dart';

class WebDavSyncEngine implements SyncTransport {
  final YatttaWebDavClient client;
  final SyncSources sources;

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
    await client.ensureYatttaFolders();

    _report('Pushing todos');
    await _pushTodos();

    _report('Pushing tasks');
    await _pushTasks();

    _report('Pushing trackers');
    await _pushTrackers();
  }

  @override
  Future<void> pull() async {
    await client.ensureYatttaFolders();

    _report('Pulling todos');
    await _pullTodos();

    _report('Pulling tasks');
    await _pullTasks();

    _report('Pulling trackers');
    await _pullTrackers();
  }

  // ---------------------------------------------------------------------
  // Todos — single file
  // ---------------------------------------------------------------------

  Future<void> _pushTodos() async {
    final todos = await sources.todos.findAllForPush();
    final content = TodoFileSerializer.serialize(todos);
    await client.write('/yattta/todos.md', _bytes(content));
  }

  Future<void> _pullTodos() async {
    final bytes = await client.read('/yattta/todos.md');
    if (bytes == null) return; // nothing remote yet — first push will create it

    final remoteTodos = TodoFileSerializer.parse(utf8.decode(bytes));

    for (final remote in remoteTodos) {
      final local = await sources.todos.findById(remote.id);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await sources.todos.upsertFromRemote(remote);
      }
    }
    // Note: todos missing from the remote file are intentionally left
    // alone rather than deleted — see design note in webdav_sync_engine
    // tests / README about accidental-deletion safety.
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
      await client.write('/yattta/tasks/$slug.md', _bytes(content));
    }
  }

  Future<void> _pullTasks() async {
    final files = await client.list('/yattta/tasks/');
    final mdFiles = files.where(
          (f) => !f.isDirectory && f.name.endsWith('.md'),
    );

    for (final file in mdFiles) {
      final bytes = await client.read(file.path);
      if (bytes == null) continue;

      final ParsedTask remote;
      try {
        remote = TaskFileSerializer.parse(utf8.decode(bytes));
      } catch (_) {
        // Malformed file (e.g. user broke the frontmatter while
        // editing) — skip it rather than crash the whole sync.
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
    final sorted = [...trackers]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    for (final tracker in sorted) {
      final content = TrackerFileSerializer.serialize(tracker);
      final slug = slugify(tracker.name);
      await client.write('/yattta/trackers/$slug.md', _bytes(content));
    }
  }

  Future<void> _pullTrackers() async {
    final files = await client.list('/yattta/trackers/');
    final mdFiles = files.where(
          (f) => !f.isDirectory && f.name.endsWith('.md'),
    );

    for (final file in mdFiles) {
      final bytes = await client.read(file.path);
      if (bytes == null) continue;

      final ParsedTracker remote;
      try {
        remote = TrackerFileSerializer.parse(utf8.decode(bytes));
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
}
