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

  Stream<int> watchTotalCompleted() {
    final query = select(pomodoroSessions)
      ..where((s) => s.status.equals(PomodoroStatus.completed.index));
    return query.watch().map((list) => list.length);
  }

  Stream<List<PomodoroSession>> watchAllCompletedTodoSessions() {
    return (select(pomodoroSessions)
          ..where((s) => s.status.equals(PomodoroStatus.completed.index) & s.todoId.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch();
  }

  Stream<List<PomodoroSession>> watchAllCompletedSessions() {
    return (select(pomodoroSessions)
          ..where((s) => s.status.equals(PomodoroStatus.completed.index))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch();
  }

  Stream<List<PomodoroSession>> watchSessionsForTodo(String todoId) {
    return (select(pomodoroSessions)
          ..where((s) => s.todoId.equals(todoId))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch();
  }

  Future<List<PomodoroSession>> getSessionsForTodo(String todoId) =>
      (select(pomodoroSessions)
        ..where((s) => s.todoId.equals(todoId))
        ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
      .get();
}
