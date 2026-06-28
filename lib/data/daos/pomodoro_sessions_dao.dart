import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/pomodoro_sessions_table.dart';
import '../converters/enum_converters.dart';

part 'pomodoro_sessions_dao.g.dart';

@DriftAccessor(tables: [PomodoroSessions])
class PomodoroSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$PomodoroSessionsDaoMixin {
  PomodoroSessionsDao(super.db);

  Future<void> insertSession(PomodoroSessionsCompanion entry) =>
      into(pomodoroSessions).insert(entry);

  Stream<int> watchCountForTodo(String todoId) {
    final query = select(pomodoroSessions)
      ..where((s) => s.todoId.equals(todoId) & s.status.equals(PomodoroStatus.completed.index));
    return query.watch().map((list) => list.length);
  }

  Stream<int> watchCountForTask(String taskId) {
    final query = select(pomodoroSessions)
      ..where((s) => s.taskId.equals(taskId) & s.status.equals(PomodoroStatus.completed.index));
    return query.watch().map((list) => list.length);
  }

  Stream<int> watchTotalCompleted() {
    final query = select(pomodoroSessions)
      ..where((s) => s.status.equals(PomodoroStatus.completed.index));
    return query.watch().map((list) => list.length);
  }
  
  Future<List<PomodoroSession>> getSessionsForTodo(String todoId) =>
      (select(pomodoroSessions)
        ..where((s) => s.todoId.equals(todoId))
        ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
      .get();

  Future<List<PomodoroSession>> getSessionsForTask(String taskId) =>
      (select(pomodoroSessions)
        ..where((s) => s.taskId.equals(taskId))
        ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
      .get();
}
