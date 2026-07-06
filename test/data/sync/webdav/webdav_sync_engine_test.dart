import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:yattta/data/sync/serializers/todo_file_serializer.dart';
import 'package:yattta/data/sync/webdav/webdav_sync_engine.dart';
import 'package:yattta/data/sync/webdav/webdav_client.dart';
import 'package:yattta/domain/sync/parsed_models.dart';
import 'package:yattta/domain/sync/synced_dao_contacts.dart';

@GenerateNiceMocks([
  MockSpec<YatttaWebDavClient>(),
  MockSpec<SyncableTodosSource>(),
  MockSpec<SyncableTasksSource>(),
  MockSpec<SyncableTrackersSource>(),
  MockSpec<SyncableRemindersSource>(),
  MockSpec<SyncableBrainDumpsSource>(),
  MockSpec<SyncableSettingsSource>(),
])
import 'webdav_sync_engine_test.mocks.dart';

void main() {
  late MockYatttaWebDavClient client;
  late MockSyncableTodosSource todos;
  late MockSyncableTasksSource tasks;
  late MockSyncableTrackersSource trackers;
  late MockSyncableRemindersSource reminders;
  late MockSyncableBrainDumpsSource brainDumps;
  late MockSyncableSettingsSource settings;
  late WebDavSyncEngine engine;

  setUp(() {
    client = MockYatttaWebDavClient();
    todos = MockSyncableTodosSource();
    tasks = MockSyncableTasksSource();
    trackers = MockSyncableTrackersSource();
    reminders = MockSyncableRemindersSource();
    brainDumps = MockSyncableBrainDumpsSource();
    settings = MockSyncableSettingsSource();

    engine = WebDavSyncEngine(
      client: client,
      sources: SyncSources(
        todos: todos,
        tasks: tasks,
        trackers: trackers,
        reminders: reminders,
        brainDumps: brainDumps,
        settings: settings,
      ),
    );
    
    // Default stubs to prevent engine from stopping early or crashing
    when(client.exists(any, isDirectory: anyNamed('isDirectory'))).thenAnswer((_) async => false);
    when(client.list(any)).thenAnswer((_) async => []);
    when(client.read(any)).thenAnswer((_) async => null);
    
    when(todos.findAllForPush()).thenAnswer((_) async => []);
    when(tasks.findAllForPush()).thenAnswer((_) async => []);
    when(trackers.findAllForPush()).thenAnswer((_) async => []);
    when(brainDumps.findAllForPush()).thenAnswer((_) async => []);
    when(settings.findAllForPush()).thenAnswer((_) async => []);
    
    when(todos.findById(any)).thenAnswer((_) async => null);
  });

  group('WebDavSyncEngine', () {
    test('push() should write all entities to their respective paths', () async {
      final now = DateTime.now();
      
      when(todos.findAllForPush()).thenAnswer((_) async => [
        ParsedTodo(id: '12345678-0001', title: 'T1', completed: false, priority: ParsedPriority.normal, updatedAt: now)
      ]);
      when(brainDumps.findAllForPush()).thenAnswer((_) async => [
        ParsedBrainDump(id: '12345678-0002', note: 'B1', isReviewed: false, createdAt: now, updatedAt: now)
      ]);
      when(settings.findAllForPush()).thenAnswer((_) async => [
        ParsedSetting(key: 'k1', value: 'v1', updatedAt: now)
      ]);
      
      await engine.push();

      verify(client.ensureYatttaFolders()).called(1);
      verify(client.write(argThat(contains('todos/normal.md')), any, ifMatch: anyNamed('ifMatch'))).called(1);
      verify(client.write(argThat(contains('todos/high.md')), any, ifMatch: anyNamed('ifMatch'))).called(1);
      verify(client.write(argThat(contains('todos/low.md')), any, ifMatch: anyNamed('ifMatch'))).called(1);
      verify(client.write(argThat(contains('braindumps/')), any, ifMatch: anyNamed('ifMatch'))).called(1);
      verify(client.write(argThat(contains('settings.yaml')), any, ifMatch: anyNamed('ifMatch'))).called(1);
    });

    test('intelligent write-skipping: should skip push if content is identical', () async {
      final now = DateTime(2023, 10, 27, 10, 0);
      final todosList = [ParsedTodo(id: '12345678-0001', title: 'Task 1', completed: false, priority: ParsedPriority.normal, updatedAt: now)];
      final content = TodoFileSerializer.serialize(todosList);
      final bytes = Uint8List.fromList(utf8.encode(content));

      when(todos.findAllForPush()).thenAnswer((_) async => todosList);
      
      // First push calls write
      await engine.push();
      verify(client.write('yattta/todos/normal.md', bytes, ifMatch: null)).called(1);

      // Second push with same content should skip write
      clearInteractions(client);
      await engine.push();
      verifyNever(client.write(any, any, ifMatch: anyNamed('ifMatch')));
    });

    test('conflict detection: should skip push if remote changed since pull', () async {
      final now = DateTime(2023, 10, 27, 10, 0);
      final initialMd = TodoFileSerializer.serialize([
        ParsedTodo(id: '12345678-0001', title: 'Task 1', completed: false, priority: ParsedPriority.normal, updatedAt: now)
      ]);
      final initialBytes = Uint8List.fromList(utf8.encode(initialMd));
      final initialEtag = 'etag-1';

      when(client.exists('yattta', isDirectory: true)).thenAnswer((_) async => true);
      when(client.list('yattta/todos')).thenAnswer((_) async => [
        YatttaFile(path: 'yattta/todos/normal.md', name: 'normal.md', isDirectory: false)
      ]);
      when(client.read('yattta/todos/normal.md')).thenAnswer((_) async => 
          YatttaReadResult(initialBytes, initialEtag));

      await engine.pull();
      
      when(todos.findAllForPush()).thenAnswer((_) async => [
        ParsedTodo(id: '12345678-0001', title: 'Local Change', completed: false, priority: ParsedPriority.normal, updatedAt: DateTime.now())
      ]);
      
      when(client.write(any, any, ifMatch: initialEtag)).thenThrow(
        YatttaWebDavException('Conflict', Exception('HTTP 412 Precondition Failed'))
      );

      // Should handle the conflict internally (last-write-wins usually, but SafeWrite honors the If-Match)
      await engine.push();
      verify(client.write('yattta/todos/normal.md', any, ifMatch: initialEtag)).called(1);
    });

    test('pull() should read and upsert from remote files', () async {
      final now = DateTime(2023, 10, 27, 10, 0);
      // ID must start with 8 hex chars for TodoFileSerializer regex to match!
      final todoMd = TodoFileSerializer.serialize([
        ParsedTodo(id: 'abcdef12-3456', title: 'Remote Task', completed: false, priority: ParsedPriority.normal, updatedAt: now)
      ]);
      
      when(client.exists('yattta', isDirectory: true)).thenAnswer((_) async => true);
      when(client.list('yattta/todos')).thenAnswer((_) async => [
        YatttaFile(path: 'yattta/todos/normal.md', name: 'normal.md', isDirectory: false)
      ]);
      when(client.read('yattta/todos/normal.md')).thenAnswer((_) async =>
          YatttaReadResult(Uint8List.fromList(utf8.encode(todoMd)), 'etag-1'));

      await engine.pull();

      verify(todos.upsertFromRemote(argThat(predicate((p) => p is ParsedTodo && p.id == 'abcdef12-3456')))).called(1);
    });

    test('pull() should handle legacy todos.md file', () async {
      final now = DateTime(2023, 10, 27, 10, 0);
      final legacyMd = TodoFileSerializer.serialize([
        ParsedTodo(id: 'deadbeef-3456', title: 'Legacy Task', completed: false, priority: ParsedPriority.normal, updatedAt: now)
      ]);

      when(client.exists('yattta', isDirectory: true)).thenAnswer((_) async => true);
      when(client.list('yattta/todos')).thenAnswer((_) async => []); // No new files
      when(client.read('yattta/todos.md')).thenAnswer((_) async =>
          YatttaReadResult(Uint8List.fromList(utf8.encode(legacyMd)), 'etag-legacy'));

      await engine.pull();

      verify(todos.upsertFromRemote(argThat(predicate((p) => p is ParsedTodo && p.id == 'deadbeef-3456')))).called(1);
    });
  });
}
