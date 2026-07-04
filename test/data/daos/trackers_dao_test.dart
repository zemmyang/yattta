import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/data/converters/enum_converters.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  group('TrackersDao', () {
    test('upsert and watchAll', () async {
      final tracker = TrackersCompanion.insert(
        id: 'tracker-1',
        title: 'Test Tracker',
        valueType: const Value(TrackerValueType.double),
        direction: const Value(TrackerDirection.decreasing),
        updatedAt: Value(DateTime.now()),
      );

      await db.trackersDao.upsert(tracker);

      final results = await db.trackersDao.watchAll().first;
      expect(results.length, 1);
      expect(results[0].title, 'Test Tracker');
    });

    test('addLog and getLogsForTracker', () async {
      await db.trackersDao.upsert(TrackersCompanion.insert(
        id: 'tracker-1',
        title: 'Test Tracker',
        updatedAt: Value(DateTime.now()),
      ));

      final log = TrackerLogsCompanion.insert(
        id: 'log-1',
        trackerId: 'tracker-1',
        value: 10.5,
        loggedAt: DateTime.now(),
        updatedAt: Value(DateTime.now()),
      );

      await db.trackersDao.addLog(log);

      final logs = await db.trackersDao.getLogsForTracker('tracker-1');
      expect(logs.length, 1);
      expect(logs[0].value, 10.5);
    });

    test('softDelete', () async {
      await db.trackersDao.upsert(TrackersCompanion.insert(
        id: 'tracker-1',
        title: 'Test Tracker',
        updatedAt: Value(DateTime.now()),
      ));

      await db.trackersDao.softDelete('tracker-1');

      final active = await db.trackersDao.watchAll().first;
      expect(active, isEmpty);
    });
  });
}
