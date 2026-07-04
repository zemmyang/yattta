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
    
    // Default stubs
    when(client.exists(any, isDirectory: anyNamed('isDirectory'))).thenAnswer((_) async => false);
    when(client.list(any)).thenAnswer((_) async => []);
    when(client.read(any)).thenAnswer((_) async => null);
  });

  group('WebDavSyncEngine', () {
    test('push() should write all entities to their respective paths', () async {
      final now = DateTime.now();
      
      when(todos.findAllForPush()).thenAnswer((_) async => [
        ParsedTodo(id: 't1-12345678', title: 'T1', completed: false, priority: ParsedPriority.normal, updatedAt: now)
      ]);
      when(tasks.findAllForPush()).thenAnswer((_) async => []);
      when(trackers.findAllForPush()).thenAnswer((_) async => []);
      when(brainDumps.findAllForPush()).thenAnswer((_) async => [
        ParsedBrainDump(id: 'b1-12345678', note: 'B1', isReviewed: false, createdAt: now, updatedAt: now)
      ]);
      when(settings.findAllForPush()).thenAnswer((_) async => [
        ParsedSetting(key: 'k1', value: 'v1', updatedAt: now)
      ]);
      
      await engine.push();

      verify(client.ensureYatttaFolders()).called(1);
      verify(client.write(argThat(contains('todos.md')), any, ifMatch: anyNamed('ifMatch'))).called(1);
      verify(client.write(argThat(contains('braindumps/')), any, ifMatch: anyNamed('ifMatch'))).called(1);
      verify(client.write(argThat(contains('settings.yaml')), any, ifMatch: anyNamed('ifMatch'))).called(1);
    });

    test('intelligent write-skipping: should skip push if content is identical', () async {
      final now = DateTime(2023, 10, 27, 10, 0);
      final todosList = [ParsedTodo(id: 't1-12345678', title: 'Task 1', completed: false, priority: ParsedPriority.normal, updatedAt: now)];
      final content = TodoFileSerializer.serialize(todosList);
      final bytes = Uint8List.fromList(utf8.encode(content));

      when(todos.findAllForPush()).thenAnswer((_) async => todosList);
      
      await engine.push();
      verify(client.write('yattta/todos.md', bytes, ifMatch: null)).called(1);

      clearInteractions(client);
      await engine.push();
      verifyNever(client.write(any, any, ifMatch: anyNamed('ifMatch')));
    });

    test('conflict detection: should skip push if remote changed since pull', () async {
      final now = DateTime(2023, 10, 27, 10, 0);
      final initialMd = TodoFileSerializer.serialize([
        ParsedTodo(id: 't1-12345678', title: 'Task 1', completed: false, priority: ParsedPriority.normal, updatedAt: now)
      ]);
      final initialBytes = Uint8List.fromList(utf8.encode(initialMd));
      final initialEtag = 'etag-1';

      when(client.exists('yattta', isDirectory: true)).thenAnswer((_) async => true);
      when(client.read('yattta/todos.md')).thenAnswer((_) async => YatttaReadResult(initialBytes, initialEtag));

      await engine.pull();
      
      final localChange = [
        ParsedTodo(id: 't1-12345678', title: 'Task 1 Local', completed: false, priority: ParsedPriority.normal, updatedAt: DateTime.now())
      ];
      when(todos.findAllForPush()).thenAnswer((_) async => localChange);
      
      when(client.write(any, any, ifMatch: initialEtag)).thenThrow(
        YatttaWebDavException('Conflict', Exception('HTTP 412 Precondition Failed'))
      );

      await engine.push();
      verify(client.write('yattta/todos.md', any, ifMatch: initialEtag)).called(1);
    });

    test('pull() should read and upsert from remote files', () async {
      final now = DateTime(2023, 10, 27, 10, 0);
      final todoMd = TodoFileSerializer.serialize([
        ParsedTodo(id: 't1-12345', title: 'Remote Task', completed: false, priority: ParsedPriority.normal, updatedAt: now)
      ]);
      
      // Use local variables to avoid capture issues
      final localClient = MockYatttaWebDavClient();
      final localTodos = MockSyncableTodosSource();
      final localTasks = MockSyncableTasksSource();
      final localTrackers = MockSyncableTrackersSource();
      final localReminders = MockSyncableRemindersSource();
      final localBrainDumps = MockSyncableBrainDumpsSource();
      final localSettings = MockSyncableSettingsSource();

      final localEngine = WebDavSyncEngine(
        client: localClient,
        sources: SyncSources(
          todos: localTodos,
          tasks: localTasks,
          trackers: localTrackers,
          reminders: localReminders,
          brainDumps: localBrainDumps,
          settings: localSettings,
        ),
      );

      when(localClient.exists(any, isDirectory: anyNamed('isDirectory'))).thenAnswer((_) async => true);
      when(localClient.read(any)).thenAnswer((_) async => null);
      when(localClient.read('yattta/todos.md')).thenAnswer((_) async => YatttaReadResult(Uint8List.fromList(utf8.encode(todoMd)), 'etag-1'));
      when(localClient.list(any)).thenAnswer((_) async => []);
      
      when(localTodos.findById(any)).thenAnswer((_) async => null);

      await localEngine.pull();

      verify(localTodos.upsertFromRemote(any)).called(1);
    });
  });
}
