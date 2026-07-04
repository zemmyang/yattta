// data/sync/serializers/braindump_file_serializer.dart
//
// Individual files: /yattta/braindumps/<timestamp>-<shortId>.md
// Follows the same pattern as Todos/Tasks: frontmatter for metadata, 
// body for the note content.

import 'package:yaml/yaml.dart';
import '../../../domain/sync/parsed_models.dart';
import 'yaml_write_utils.dart';

class BraindumpFileSerializer {
  static final RegExp _lineRe = RegExp(r'^- \[( |x)\] (.*?) `([a-f0-9]{8})`\s*$', multiLine: true);

  /// Serializes a single braindump into a markdown file with frontmatter.
  static String serializeSingle(ParsedBrainDump d) {
    final buf = StringBuffer();

    buf.writeln('---');
    buf.write(yamlMap({
      'id': d.id,
      'created': d.createdAt,
      'updated': d.updatedAt,
      'reviewed': d.isReviewed,
      if (d.tags.isNotEmpty) 'tags': d.tags,
    }));
    buf.writeln('---');
    buf.writeln();
    // Body is raw markdown; we don't escape newlines here because 
    // it's a dedicated file, unlike the single-file list format.
    buf.writeln(d.note.trim());
    buf.writeln();

    return buf.toString();
  }

  /// Parses a single braindump file content.
  static ParsedBrainDump parseSingle(String content) {
    final delimiter = RegExp(r'^---\s*$', multiLine: true);
    final parts = content.split(delimiter);
    if (parts.length < 3) {
      throw FormatException('Braindump file missing frontmatter delimiters');
    }

    final meta = loadYaml(parts[1]) as YamlMap;
    final body = parts.sublist(2).join('---\n').trim();

    return ParsedBrainDump(
      id: meta['id'] as String,
      note: body,
      isReviewed: meta['reviewed'] as bool? ?? false,
      tags: meta['tags'] != null
          ? List<String>.from(meta['tags'] as YamlList)
          : const [],
      createdAt: DateTime.parse(meta['created'].toString()),
      updatedAt: DateTime.parse(meta['updated'].toString()),
    );
  }

  /// Legacy serializer for the single-file format.
  static String serialize(List<ParsedBrainDump> dumps) {
    final buf = StringBuffer();

    buf.writeln('---');
    buf.writeln('sync:');
    for (final d in dumps) {
      buf.writeln('  - id: ${d.id}');
      buf.write(yamlMap({
        'created': d.createdAt,
        'updated': d.updatedAt,
        if (d.tags.isNotEmpty) 'tags': d.tags,
      }, indent: 2));
    }
    buf.writeln('---');
    buf.writeln();
    buf.writeln('# Brain Dumps');
    buf.writeln();

    for (final d in dumps) {
      final check = d.isReviewed ? 'x' : ' ';
      final shortId = d.id.substring(0, 8);
      // In the list format, we MUST escape newlines to keep it one line per entry.
      buf.writeln('- [$check] ${escapeMd(d.note)} `$shortId`');
    }
    buf.writeln();

    return buf.toString();
  }

  /// Legacy parser for the single-file format.
  static List<ParsedBrainDump> parse(String content) {
    final delimiter = RegExp(r'^---\s*$', multiLine: true);
    final parts = content.split(delimiter);
    if (parts.length < 3) return [];

    final yamlDoc = loadYaml(parts[1]);
    final syncList = (yamlDoc is Map ? yamlDoc['sync'] : null) as YamlList?;

    final metaById = <String, YamlMap>{};
    if (syncList != null) {
      for (final entry in syncList) {
        final e = entry as YamlMap;
        final fullId = e['id'] as String;
        metaById[fullId] = e;
      }
    }

    final metaByShortId = <String, YamlMap>{};
    metaById.forEach((id, meta) {
      metaByShortId[id.substring(0, 8)] = meta;
    });

    final body = parts.sublist(2).join('---\n');
    final result = <ParsedBrainDump>[];

    for (final m in _lineRe.allMatches(body)) {
      final shortId = m.group(3)!;
      final meta = metaByShortId[shortId];
      if (meta == null) continue;

      result.add(ParsedBrainDump(
        id: meta['id'] as String,
        note: m.group(2)!.trim(),
        isReviewed: m.group(1) == 'x',
        tags: meta['tags'] != null
            ? List<String>.from(meta['tags'] as YamlList)
            : const [],
        createdAt: meta['created'] != null 
          ? DateTime.parse(meta['created'].toString())
          : DateTime.parse(meta['updated'].toString()), // Fallback
        updatedAt: DateTime.parse(meta['updated'].toString()),
      ));
    }

    return result;
  }
}
