// presentation/providers/database_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/daos/todos_dao.dart';
import '../../data/daos/tasks_dao.dart';
import '../../data/daos/trackers_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>(
      (ref) => db,
);

final todosDaoProvider = Provider(
      (ref) => ref.watch(appDatabaseProvider).todosDao,
);

final tasksDaoProvider = Provider(
      (ref) => ref.watch(appDatabaseProvider).tasksDao,
);

final trackersDaoProvider = Provider(
      (ref) => ref.watch(appDatabaseProvider).trackersDao,
);

final remindersDaoProvider = Provider(
      (ref) => ref.watch(appDatabaseProvider).remindersDao,
);

final tagsDaoProvider = Provider(
      (ref) => ref.watch(appDatabaseProvider).tagsDao,
);

final pomodoroSessionsDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).pomodoroSessionsDao,
);

final tagsStreamProvider = StreamProvider((ref) {
  return ref.watch(tagsDaoProvider).watchAll();
});

final deletedTagsProvider = StreamProvider((ref) {
  return ref.watch(tagsDaoProvider).watchDeleted();
});

final activeTasksProvider = StreamProvider((ref) {
  return ref.watch(tasksDaoProvider).watchAll();
});

final todayLogsProvider = StreamProvider((ref) {
  return ref.watch(tasksDaoProvider).watchLogsForDay(DateTime.now());
});

final activeRemindersProvider = StreamProvider((ref) {
  return ref.watch(remindersDaoProvider).watchAllActive();
});

final trackersProvider = StreamProvider((ref) {
  return ref.watch(trackersDaoProvider).watchAllWithTags();
});

final deletedTrackersProvider = StreamProvider((ref) {
  return ref.watch(trackersDaoProvider).watchDeleted();
});

final todosProvider = StreamProvider((ref) {
  return ref.watch(todosDaoProvider).watchAllWithTags();
});

final deletedTodosProvider = StreamProvider((ref) {
  return ref.watch(todosDaoProvider).watchDeleted();
});

final tasksWithTagsProvider = StreamProvider((ref) {
  return ref.watch(tasksDaoProvider).watchAllWithTags();
});

final deletedTasksProvider = StreamProvider((ref) {
  return ref.watch(tasksDaoProvider).watchDeleted();
});

class TagWithItems {
  final Tag tag;
  final List<TodoWithTags> todos;
  final List<TaskWithTags> tasks;
  final List<TrackerWithTags> trackers;

  TagWithItems({
    required this.tag,
    required this.todos,
    required this.tasks,
    required this.trackers,
  });
}

final tagsWithItemsProvider = Provider<AsyncValue<List<TagWithItems>>>((ref) {
  final tags = ref.watch(tagsStreamProvider);
  final todos = ref.watch(todosProvider);
  final trackers = ref.watch(trackersProvider);
  final tasks = ref.watch(tasksWithTagsProvider);

  if (tags.isLoading || todos.isLoading || trackers.isLoading || tasks.isLoading) {
    return const AsyncValue.loading();
  }

  if (tags.hasError) return AsyncValue.error(tags.error!, tags.stackTrace!);
  if (todos.hasError) return AsyncValue.error(todos.error!, todos.stackTrace!);
  if (trackers.hasError) return AsyncValue.error(trackers.error!, trackers.stackTrace!);
  if (tasks.hasError) return AsyncValue.error(tasks.error!, tasks.stackTrace!);

  final result = tags.value!.map((tag) => TagWithItems(
    tag: tag,
    todos: todos.value!.where((item) => item.tags.any((t) => t.id == tag.id)).toList(),
    tasks: tasks.value!.where((item) => item.tags.any((t) => t.id == tag.id)).toList(),
    trackers: trackers.value!.where((item) => item.tags.any((t) => t.id == tag.id)).toList(),
  )).toList();

  return AsyncValue.data(result);
});
