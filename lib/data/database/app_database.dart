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
import '../tables/brain_dumps_table.dart';

import '../daos/todos_dao.dart';
import '../daos/tasks_dao.dart';
import '../daos/trackers_dao.dart';
import '../daos/reminders_dao.dart';
import '../daos/tags_dao.dart';
import '../daos/settings_dao.dart';
import '../daos/pomodoro_sessions_dao.dart';
import '../daos/brain_dumps_dao.dart';

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
    BrainDumpTags,
    Settings,
    BrainDumps,
  ],
  daos: [
    TodosDao,
    TasksDao,
    TrackersDao,
    RemindersDao,
    TagsDao,
    SettingsDao,
    PomodoroSessionsDao,
    BrainDumpsDao,
  ],
)

class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());
  AppDatabase.forTesting(DatabaseConnection super.connection);

  @override
  int get schemaVersion => 5;

  // Migrations go here as schemaVersion grows
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Add work_duration and break_duration to todos
        await m.addColumn(todos, todos.workDuration);
        await m.addColumn(todos, todos.breakDuration);
      }
      if (from < 3) {
        await m.createTable(brainDumps);
      }
      if (from < 4) {
        await m.createTable(brainDumpTags);
      }
      if (from < 5) {
        // Add unique index to tags name (case-insensitive)
        // Handle existing duplicates by merging them.
        
        await transaction(() async {
          // 1. Find all duplicate names (case-insensitive)
          final duplicates = await customSelect(
            'SELECT LOWER(name) as lower_name FROM tags GROUP BY LOWER(name) HAVING COUNT(*) > 1',
          ).get();

          for (final row in duplicates) {
            final lowerName = row.read<String>('lower_name');
            
            // 2. Get all tags with this name (case-insensitive)
            final tagsWithSameName = await (select(tags)
              ..where((t) => t.name.lower().equals(lowerName))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();

            if (tagsWithSameName.length > 1) {
              final primaryTag = tagsWithSameName.first;
              final duplicatesToMerge = tagsWithSameName.skip(1);

              for (final duplicate in duplicatesToMerge) {
                // 3. Update junction tables to point to the primary tag
                // We use ignore to avoid primary key violations if both tags were already attached
                await customStatement('UPDATE OR IGNORE todo_tags SET tag_id = ? WHERE tag_id = ?', [primaryTag.id, duplicate.id]);
                await customStatement('UPDATE OR IGNORE task_tags SET tag_id = ? WHERE tag_id = ?', [primaryTag.id, duplicate.id]);
                await customStatement('UPDATE OR IGNORE tracker_tags SET tag_id = ? WHERE tag_id = ?', [primaryTag.id, duplicate.id]);
                await customStatement('UPDATE OR IGNORE brain_dump_tags SET tag_id = ? WHERE tag_id = ?', [primaryTag.id, duplicate.id]);
                
                // Delete the old junction entries that weren't updated due to IGNORE
                await customStatement('DELETE FROM todo_tags WHERE tag_id = ?', [duplicate.id]);
                await customStatement('DELETE FROM task_tags WHERE tag_id = ?', [duplicate.id]);
                await customStatement('DELETE FROM tracker_tags WHERE tag_id = ?', [duplicate.id]);
                await customStatement('DELETE FROM brain_dump_tags WHERE tag_id = ?', [duplicate.id]);

                // 4. Delete the duplicate tag
                await customStatement('DELETE FROM tags WHERE id = ?', [duplicate.id]);
              }
            }
          }

          // 5. Create the unique index
          await m.createIndex(Index('tags', 'CREATE UNIQUE INDEX tags_name_unique ON tags (name COLLATE NOCASE)'));
        });
      }
    },
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
