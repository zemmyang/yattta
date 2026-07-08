import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  group('TagsDao', () {
    test('prevent duplicate tag names', () async {
      await db.tagsDao.upsert(TagsCompanion.insert(
        id: 'tag-1',
        name: 'Work',
      ));

      // Try to insert another tag with the same name
      expect(
        () => db.tagsDao.upsert(TagsCompanion.insert(
          id: 'tag-2',
          name: 'Work',
        )),
        throwsA(isA<SqliteException>()),
      );
    });

    test('upsert allows updating existing tag name', () async {
      await db.tagsDao.upsert(TagsCompanion.insert(
        id: 'tag-1',
        name: 'Work',
      ));

      // Update the same tag
      await db.tagsDao.upsert(TagsCompanion.insert(
        id: 'tag-1',
        name: 'Work Updated',
      ));

      final tags = await db.tagsDao.getAllTags();
      expect(tags.length, 1);
      expect(tags[0].name, 'Work Updated');
    });

    test('case-insensitive unique constraint', () async {
       await db.tagsDao.upsert(TagsCompanion.insert(
        id: 'tag-1',
        name: 'Work',
      ));

      // With COLLATE NOCASE, this should throw
      expect(
        () => db.tagsDao.upsert(TagsCompanion.insert(
          id: 'tag-2',
          name: 'work',
        )),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
