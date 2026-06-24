// app_database.dart
import 'package:drift/drift.dart';
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
