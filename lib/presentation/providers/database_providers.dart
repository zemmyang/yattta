// presentation/providers/database_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

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

final todosProvider = StreamProvider((ref) {
  return ref.watch(todosDaoProvider).watchAllWithTags();
});
