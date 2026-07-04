// data/sync/serializers/settings_file_serializer.dart
//
// Single file: /yattta/settings.yaml
// Simple key-value store for app preferences.

import 'package:yaml/yaml.dart';
import '../../../domain/sync/parsed_models.dart';
import 'yaml_write_utils.dart';

class SettingsFileSerializer {
  static String serialize(List<ParsedSetting> settings) {
    final buf = StringBuffer();
    buf.writeln('---');
    for (final s in settings) {
      // Skip WebDAV credentials to avoid circular dependency and security risks
      if (s.key.startsWith('webDav')) continue;
      
      buf.writeln('${s.key}:');
      buf.write(yamlMap({
        'value': s.value,
        'updated': s.updatedAt,
      }, indent: 1));
    }
    buf.writeln('---');
    return buf.toString();
  }

  static List<ParsedSetting> parse(String content) {
    final delimiter = RegExp(r'^---\s*$', multiLine: true);
    final parts = content.split(delimiter);
    if (parts.length < 3) return [];

    final yamlDoc = loadYaml(parts[1]);
    if (yamlDoc is! YamlMap) return [];

    final result = <ParsedSetting>[];
    for (final entry in yamlDoc.entries) {
      final key = entry.key as String;
      final data = entry.value as YamlMap;
      
      result.add(ParsedSetting(
        key: key,
        value: data['value'].toString(),
        updatedAt: DateTime.parse(data['updated'].toString()),
      ));
    }

    return result;
  }
}
