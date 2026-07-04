import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/pages/trackers.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/data/converters/enum_converters.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTrackersPage() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          ...FLocalizations.localizationsDelegates,
        ],
        home: TrackersPage(),
      ),
    );
  }

  group('TrackersPage', () {
    testWidgets('shows empty state when no trackers', (tester) async {
      await tester.pumpWidget(createTrackersPage());
      await tester.pumpAndSettle();

      expect(find.text('No trackers yet. Add one!'), findsOneWidget);
    });

    testWidgets('renders trackers with units', (tester) async {
      await db.trackersDao.upsert(TrackersCompanion.insert(
        id: 'tracker-1',
        title: 'Weight',
        unit: const Value('kg'),
        valueType: const Value(TrackerValueType.double),
        direction: const Value(TrackerDirection.decreasing),
        updatedAt: Value(DateTime.now()),
      ));

      await tester.pumpWidget(createTrackersPage());
      await tester.pumpAndSettle();

      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Unit: kg'), findsOneWidget);
    });

    testWidgets('can log a value', (tester) async {
      await db.trackersDao.upsert(TrackersCompanion.insert(
        id: 'tracker-1',
        title: 'Water',
        unit: const Value('glasses'),
        valueType: const Value(TrackerValueType.integer),
        updatedAt: Value(DateTime.now()),
      ));

      await tester.pumpWidget(createTrackersPage());
      await tester.pumpAndSettle();

      // Find text field and enter value
      final textField = find.byType(FTextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, '5');

      // Find check button and tap it
      final logButton = find.byIcon(FLucideIcons.check);
      await tester.tap(logButton);
      await tester.pumpAndSettle();

      // Verify log in DB
      final logs = await db.trackersDao.getLogsForTracker('tracker-1');
      expect(logs, isNotEmpty);
      expect(logs[0].value, 5.0);
    });
  });
}
