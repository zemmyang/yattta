import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(drift.DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await database.close();
  });

  test('timers can be created and watched', () async {
    final dao = database.timersDao;
    final id = const Uuid().v4();
    final now = DateTime.now();

    await dao.upsert(TimersCompanion.insert(
      id: id,
      label: const drift.Value('Test Timer'),
      durationSeconds: 60,
      startedAt: now,
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    ));

    final timers = await dao.watchAll().first;
    expect(timers.length, 1);
    expect(timers.first.id, id);
    expect(timers.first.label, 'Test Timer');
  });

  test('timers can be cancelled', () async {
    final dao = database.timersDao;
    final id = const Uuid().v4();
    final now = DateTime.now();

    await dao.upsert(TimersCompanion.insert(
      id: id,
      durationSeconds: 60,
      startedAt: now,
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    ));

    await dao.markCancelled(id);

    final timers = await dao.watchAll().first;
    expect(timers.first.isCancelled, true);
  });

  test('timers can be soft deleted', () async {
    final dao = database.timersDao;
    final id = const Uuid().v4();
    final now = DateTime.now();

    await dao.upsert(TimersCompanion.insert(
      id: id,
      durationSeconds: 60,
      startedAt: now,
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    ));

    await dao.softDelete(id);

    final timers = await dao.watchAll().first;
    expect(timers.isEmpty, true);
  });
}
