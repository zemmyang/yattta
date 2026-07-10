import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/pages/task_details.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/domain/models/recurrence_rule.dart';
import 'package:yattta/utils/settings_controller.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    // Avoid calling settingsController.initialize(db) because it uses FlutterSecureStorage,
    // which is not available in unit tests and causes MissingPluginException.
    // Instead, we manually set the required fields for the test.
    settingsController.setUserMode(UserMode.powerUser);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTaskDetailsPage(Task task) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          ...FLocalizations.localizationsDelegates,
        ],
        home: TaskDetailsPage(task: task, tags: const []),
      ),
    );
  }

  group('TaskDetailsPage', () {
    testWidgets('does not show history entries before task creation date', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Created today
      final task = Task(
        id: 'task-1',
        title: 'Daily Task',
        recurrenceRule: const RecurrenceRule(frequency: 'daily'),
        createdAt: today,
        updatedAt: today,
        isActive: true,
        position: 0,
      );

      await tester.pumpWidget(createTaskDetailsPage(task));
      await tester.pumpAndSettle();

      // Wait for any async providers to settle
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Find by type FBadge and matching text
      final notDoneBadge = find.ancestor(
        of: find.text('NOTDONE'),
        matching: find.byType(FBadge),
      ).first;
      
      expect(notDoneBadge, findsOneWidget);
      
      await tester.tap(notDoneBadge);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('No history matching filters.'), findsOneWidget);
    });

    testWidgets('shows history entries only from creation date onwards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      
      // Created yesterday
      final task = Task(
        id: 'task-2',
        title: 'Yesterday Task',
        recurrenceRule: const RecurrenceRule(frequency: 'daily'),
        createdAt: yesterday,
        updatedAt: yesterday,
        isActive: true,
        position: 0,
      );

      await tester.pumpWidget(createTaskDetailsPage(task));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final notDoneBadge = find.ancestor(
        of: find.text('NOTDONE'),
        matching: find.byType(FBadge),
      ).first;

      expect(notDoneBadge, findsOneWidget);
      await tester.tap(notDoneBadge);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Should show yesterday as "NOT DONE"
      final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      expect(find.text(yesterdayStr), findsOneWidget);
      
      // Should NOT show the day before yesterday
      final dayBeforeYesterday = yesterday.subtract(const Duration(days: 1));
      final dayBeforeYesterdayStr = "${dayBeforeYesterday.year}-${dayBeforeYesterday.month.toString().padLeft(2, '0')}-${dayBeforeYesterday.day.toString().padLeft(2, '0')}";
      expect(find.text(dayBeforeYesterdayStr), findsNothing);
    });
  });
}
