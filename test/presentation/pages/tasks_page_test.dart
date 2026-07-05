import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/pages/tasks.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/domain/models/recurrence_rule.dart';
import 'package:yattta/data/converters/enum_converters.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTasksPage() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          ...FLocalizations.localizationsDelegates,
        ],
        home: TasksPage(),
      ),
    );
  }

  group('TasksPage', () {
    testWidgets('shows empty state when no tasks', (tester) async {
      await tester.pumpWidget(createTasksPage());
      await tester.pumpAndSettle();

      expect(find.text('No active tasks. Add one!'), findsOneWidget);
    });

    testWidgets('renders tasks in correct groups', (tester) async {
      await db.tasksDao.upsert(TasksCompanion.insert(
        id: 'task-1',
        title: 'No Reminder Task',
        recurrenceRule: const RecurrenceRule(frequency: 'none'),
        updatedAt: Value(DateTime.now()),
      ));

      await tester.pumpWidget(createTasksPage());
      await tester.pumpAndSettle();

      expect(find.text('No Reminder Task'), findsOneWidget);
      expect(find.text('No reminders set'), findsOneWidget);
    });

    testWidgets('can mark task as done', (tester) async {
      await db.tasksDao.upsert(TasksCompanion.insert(
        id: 'task-1',
        title: 'Do This',
        recurrenceRule: const RecurrenceRule(frequency: 'none'),
        updatedAt: Value(DateTime.now()),
      ));

      await tester.pumpWidget(createTasksPage());
      await tester.pumpAndSettle();

      final checkbox = find.byType(FCheckbox);
      expect(checkbox, findsOneWidget);
      
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      final logs = await db.tasksDao.getLogsForTask('task-1');
      expect(logs, isNotEmpty);
      expect(logs[0].status, TaskLogStatus.done);
    });

    testWidgets('can skip task', (tester) async {
      await db.tasksDao.upsert(TasksCompanion.insert(
        id: 'task-1',
        title: 'Maybe Not',
        recurrenceRule: const RecurrenceRule(frequency: 'none'),
        updatedAt: Value(DateTime.now()),
      ));

      await tester.pumpWidget(createTasksPage());
      await tester.pumpAndSettle();

      final skipButton = find.byIcon(FLucideIcons.circleSlash);
      expect(skipButton, findsOneWidget);

      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      final logs = await db.tasksDao.getLogsForTask('task-1');
      expect(logs, isNotEmpty);
      expect(logs[0].status, TaskLogStatus.skipped);
    });
  });
}
