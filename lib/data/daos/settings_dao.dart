import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/settings.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> getString(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<int?> getInt(String key) async {
    final val = await getString(key);
    return val != null ? int.tryParse(val) : null;
  }

  Future<bool?> getBool(String key) async {
    final val = await getString(key);
    return val != null ? val == 'true' : null;
  }

  Future<void> setString(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: Value(key),
        value: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setInt(String key, int value) => setString(key, value.toString());
  Future<void> setBool(String key, bool value) => setString(key, value.toString());

  Future<void> deleteAll() => delete(settings).go();
}
