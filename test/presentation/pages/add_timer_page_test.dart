import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/pages/add_timer_page.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:flutter_picker_plus/picker.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  Widget createAddTimerPage() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          ...FLocalizations.localizationsDelegates,
        ],
        home: AddTimerPage(),
      ),
    );
  }

  group('AddTimerPage', () {
    testWidgets('renders duration field', (tester) async {
      await tester.pumpWidget(createAddTimerPage());
      await tester.pumpAndSettle();

      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Select HH:MM:SS'), findsOneWidget);
    });

    testWidgets('can open picker and select duration', (tester) async {
      await tester.pumpWidget(createAddTimerPage());
      await tester.pumpAndSettle();

      // Tap to open picker
      await tester.tap(find.text('Select HH:MM:SS'));
      await tester.pumpAndSettle();

      // Verify picker is shown
      expect(find.byType(PickerWidget), findsOneWidget);

      // In tests, we can find the state of the PickerWidget
      final pickerWidget = tester.state<PickerWidgetState>(find.byType(PickerWidget));
      final picker = pickerWidget.picker;
      
      // Simulate selecting 01:05:30
      // NumberPickerAdapter value is indices. Column 0: 1 (1h), Column 1: 5 (5m), Column 2: 30 (30s)
      picker.onConfirm!(picker, [1, 5, 30]);
      await tester.pumpAndSettle();

      // Verify the formatted duration is shown in the field
      expect(find.text('01:05:30'), findsOneWidget);

      // Tap start button
      await tester.tap(find.text('Start Timer'));
      await tester.pumpAndSettle();

      // Verify timer in DB
      final timers = await db.timersDao.watchAll().first;
      expect(timers, isNotEmpty);
      expect(timers[0].durationSeconds, 3930);
    });
  });
}
