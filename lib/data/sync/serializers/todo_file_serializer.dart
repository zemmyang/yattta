// data/sync/serializers/todo_file_serializer.dart
//
// Single file: /yattta/todos.md
// Frontmatter holds all metadata keyed by full id. Body is a plain
// checkbox list using an 8-char short id so the visible text stays
// clean and readable in Nextcloud Text.

import 'package:yaml/yaml.dart';

import '../../../domain/sync/parsed_models.dart';
import 'yaml_write_utils.dart';

class TodoFileSerializer {
  static final RegExp _lineRe =
  RegExp(r'^- \[( |x)\] (?:\((H|L)\) )?(.+?) `([a-f0-9]{8})`\s*$', multiLine: true);

  static String serialize(List<ParsedTodo> todos) {
    final buf = StringBuffer();

    buf.writeln('---');
    buf.writeln('sync:');
    for (final t in todos) {
      buf.writeln('  - id: ${t.id}');
      buf.write(yamlMap({
        if (t.dueAt != null) 'due': _fmtDate(t.dueAt!),
        if (t.priority != ParsedPriority.normal) 'priority': t.priority.name,
        if (t.tags.isNotEmpty) 'tags': t.tags,
        'updated': t.updatedAt,
      }, indent: 2));
    }
    buf.writeln('---');
    buf.writeln();
    buf.writeln('# Todos');
    buf.writeln();

    for (final t in todos) {
      final check = t.completed ? 'x' : ' ';
      final shortId = t.id.substring(0, 8);
      final priorityLabel = switch (t.priority) {
        ParsedPriority.high => '(H) ',
        ParsedPriority.low => '(L) ',
        ParsedPriority.normal => '',
      };
      buf.writeln('- [$check] $priorityLabel${escapeMd(t.title)} `$shortId`');
    }
    buf.writeln();

    return buf.toString();
  }

  static List<ParsedTodo> parse(String content) {
    final delimiter = RegExp(r'^---\s*$', multiLine: true);
    final parts = content.split(delimiter);
    if (parts.length < 3) return [];

    final yamlDoc = loadYaml(parts[1]);
    final syncList = (yamlDoc is Map ? yamlDoc['sync'] : null) as YamlList?;

    // Map short-id (first 8 chars) -> full metadata entry.
    final metaByShortId = <String, YamlMap>{};
    if (syncList != null) {
      for (final entry in syncList) {
        final e = entry as YamlMap;
        final fullId = e['id'] as String;
        metaByShortId[fullId.substring(0, 8)] = e;
      }
    }

    final body = parts.sublist(2).join('---\n');
    final result = <ParsedTodo>[];

    for (final m in _lineRe.allMatches(body)) {
      final shortId = m.group(4)!;
      final meta = metaByShortId[shortId];
      if (meta == null) continue; // orphaned line with no frontmatter entry

      final labelPriority = switch (m.group(2)) {
        'H' => ParsedPriority.high,
        'L' => ParsedPriority.low,
        _ => null,
      };

      result.add(ParsedTodo(
        id: meta['id'] as String,
        title: m.group(3)!.trim(),
        completed: m.group(1) == 'x',
        dueAt: meta['due'] != null
            ? DateTime.tryParse(meta['due'].toString())
            : null,
        priority: labelPriority ?? _parsePriority(meta['priority']?.toString()),
        tags: meta['tags'] != null
            ? List<String>.from(meta['tags'] as YamlList)
            : const [],
        updatedAt: DateTime.parse(meta['updated'].toString()),
      ));
    }

    return result;
  }

  static ParsedPriority _parsePriority(String? raw) {
    switch (raw) {
      case 'high':
        return ParsedPriority.high;
      case 'low':
        return ParsedPriority.low;
      default:
        return ParsedPriority.normal;
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
}
