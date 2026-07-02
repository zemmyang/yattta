// data/sync/serializers/yaml_write_utils.dart
//
// The `yaml` package only parses YAML, it doesn't write it. These files
// are simple enough (flat or one-level-nested maps/lists) that a small
// hand-rolled emitter is more predictable than pulling in a second
// dependency. Keep it boring and deterministic.

String slugify(String title) {
  final lower = title.toLowerCase().trim();
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final trimmed = cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
  return trimmed.isEmpty ? 'untitled' : trimmed;
}

/// Emits a flat YAML mapping. Values may be String, num, bool, DateTime,
/// List<String>, or null (omitted entries should simply not be passed).
String yamlMap(Map<String, dynamic> data, {int indent = 0}) {
  final pad = '  ' * indent;
  final buf = StringBuffer();
  for (final entry in data.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value == null) continue;
    if (value is List) {
      if (value.isEmpty) continue;
      buf.writeln('$pad$key: [${value.map(_scalar).join(', ')}]');
    } else {
      buf.writeln('$pad$key: ${_scalar(value)}');
    }
  }
  return buf.toString();
}

String _scalar(dynamic value) {
  if (value is String) {
    // Quote if it contains characters that would confuse a YAML parser.
    final needsQuote = value.contains(':') ||
        value.contains('#') ||
        value.trim() != value ||
        value.isEmpty;
    return needsQuote ? '"${value.replaceAll('"', r'\"')}"' : value;
  }
  if (value is DateTime) return value.toIso8601String();
  return value.toString();
}

String escapeMd(String text) {
  // Keep titles from accidentally breaking table/list syntax.
  return text.replaceAll('|', r'\|').replaceAll('\n', ' ').trim();
}
