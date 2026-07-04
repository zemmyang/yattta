import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/data/sync/serializers/settings_file_serializer.dart';
import 'package:yattta/domain/sync/parsed_models.dart';

void main() {
  group('SettingsFileSerializer', () {
    final now = DateTime(2023, 10, 27, 10, 0);

    test('should serialize and parse settings', () {
      final settings = [
        ParsedSetting(
          key: 'timerDuration',
          value: '25',
          updatedAt: now,
        ),
        ParsedSetting(
          key: 'userMode',
          value: 'powerUser',
          updatedAt: now,
        ),
        ParsedSetting(
          key: 'webDavPassword',
          value: 'secret',
          updatedAt: now,
        ),
      ];

      final output = SettingsFileSerializer.serialize(settings);

      expect(output, contains('timerDuration:'));
      expect(output, contains('userMode:'));
      expect(output, isNot(contains('webDavPassword:')));

      final result = SettingsFileSerializer.parse(output);

      expect(result.length, 2);
      expect(result.any((s) => s.key == 'timerDuration' && s.value == '25'), true);
      expect(result.any((s) => s.key == 'userMode' && s.value == 'powerUser'), true);
    });
  });
}
