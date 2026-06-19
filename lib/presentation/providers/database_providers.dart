// presentation/providers/database_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>(
      (ref) {
    final db = AppDatabase();
    ref.onDispose(db.close);
    return db;
  },
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