// data/sync/serializers/tracker_file_serializer.dart
//
// One file per tracker: /yattta/trackers/<slug>.md

import 'package:yaml/yaml.dart';
import '../../../domain/sync/parsed_models.dart';
import 'yaml_write_utils.dart';

class TrackerFileSerializer {
  static final RegExp _headingRe = RegExp(r'^#\s+(.+?)\s*$', multiLine: true);
  static final RegExp _rowRe = RegExp(
    r'^\|\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}(?::\d{2})?)\s*\|\s*([\d\.]+)\s*\|$',
    multiLine: true,
  );

  static String serialize(ParsedTracker tracker) {
    final buf = StringBuffer();

    buf.writeln('---');
    buf.write(yamlMap({
      'id': tracker.id,
      'order': tracker.displayOrder,
      'type': tracker.valueType.name,
      'unit': tracker.unit,
      'goal': tracker.goalDirection.name,
      if (tracker.tags.isNotEmpty) 'tags': tracker.tags,
      if (tracker.reminders.isNotEmpty) 'reminders': tracker.reminders,
      'updated': tracker.updatedAt.toIso8601String(),
    }));
    buf.writeln('---');
    buf.writeln();
    buf.writeln('# ${escapeMd(tracker.name)}');
    buf.writeln();
    buf.writeln('| Timestamp        | Value |');
    buf.writeln('|------------------|-------|');

    final sortedLogs = [...tracker.logs]
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    for (final log in sortedLogs) {
      buf.writeln('| ${_fmtTime(log.loggedAt)} | ${log.value} |');
    }
    buf.writeln();

    return buf.toString();
  }

  static ParsedTracker parse(String content) {
    final delimiter = RegExp(r'^---\s*$', multiLine: true);
    final parts = content.split(delimiter);
    if (parts.length < 3) {
      throw FormatException('Tracker file missing frontmatter');
    }

    final meta = loadYaml(parts[1]) as YamlMap;
    final body = parts.sublist(2).join('---\n');

    final titleMatch = _headingRe.firstMatch(body);
    final title = titleMatch?.group(1)?.trim() ?? 'Untitled';

    final logs = _rowRe.allMatches(body).map((m) {
      return ParsedTrackerLog(
        loggedAt: DateTime.parse(m.group(1)!),
        value: double.parse(m.group(2)!),
      );
    }).toList();

    return ParsedTracker(
      id: meta['id'] as String,
      name: title,
      displayOrder: meta['order'] as int? ?? 0,
      valueType: ParsedValueType.values.byName(meta['type'] as String),
      unit: meta['unit']?.toString() ?? '',
      goalDirection: ParsedGoalDirection.values.byName(meta['goal'] as String),
      tags: meta['tags'] != null ? List<String>.from(meta['tags'] as YamlList) : const [],
      reminders: meta['reminders'] != null ? List<String>.from(meta['reminders'] as YamlList) : const [],
      updatedAt: DateTime.parse(meta['updated'].toString()),
      logs: logs,
    );
  }

  static String _fmtTime(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}
