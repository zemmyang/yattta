// app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'connection/connection.dart';

import '../tables/todos_table.dart';
import '../tables/tasks_table.dart';
import '../tables/task_logs_table.dart';
import '../tables/trackers_table.dart';
import '../tables/tracker_logs_table.dart';
import '../tables/pomodoro_sessions_table.dart';
import '../tables/reminders_table.dart';
import '../tables/tags_table.dart';
import '../tables/junction_tables.dart';
import '../tables/settings.dart';

import '../daos/todos_dao.dart';
import '../daos/tasks_dao.dart';
import '../daos/trackers_dao.dart';
import '../daos/reminders_dao.dart';
import '../daos/tags_dao.dart';
import '../daos/settings_dao.dart';

import '../../domain/models/recurrence_rule.dart';
import '../converters/recurrence_rule_converter.dart';
import "../converters/enum_converters.dart";

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Todos,
    Tasks,
    TaskLogs,
    Trackers,
    TrackerLogs,
    PomodoroSessions,
    Reminders,
    Tags,
    TodoTags,
    TaskTags,
    TrackerTags,
    Settings,
  ],
  daos: [
    TodosDao,
    TasksDao,
    TrackersDao,
    RemindersDao,
    TagsDao,
    SettingsDao,
  ],
)

class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());

  @override
  int get schemaVersion => 1;

  // Migrations go here as schemaVersion grows
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
  );
}

final db = AppDatabase();

Future<void> deleteDatabaseFile() async {
  await db.close();
  if (identical(0, 0.0)) {
    // Web - Drift doesn't have a simple way to delete IndexedDB via its API here
    // But we can clear tables at least if needed, or just let users clear browser data
    return;
  }
  
  // Native
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error deleting database: $e');
    }
  }
}
