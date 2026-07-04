// data/sync/serializers/task_file_serializer.dart
//
// One file per habit-task: /yattta/tasks/<slug>.md
// Frontmatter is the source of truth for id/order/recurrence/tags/
// reminders. The `order` field controls position in the UI list since
// files in a folder have no inherent ordering of their own.

import 'package:yaml/yaml.dart';

import '../../../domain/sync/parsed_models.dart';
import 'yaml_write_utils.dart';

class TaskFileSerializer {
  static final RegExp _headingRe = RegExp(r'^#\s+(.+?)\s*$', multiLine: true);
  static final RegExp _rowRe = RegExp(
    r'^\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*(✓|✗|skip)?\s*\|\s*(.*?)\s*\|\s*$',
    multiLine: true,
  );

  static String serialize(ParsedTask task) {
    final buf = StringBuffer();

    buf.writeln('---');
    buf.write(yamlMap({
      'id': task.id,
      'order': task.displayOrder,
      if (task.recurrence != null) 'recurrence': task.recurrence,
      if (task.tags.isNotEmpty) 'tags': task.tags,
      if (task.reminders.isNotEmpty) 'reminders': task.reminders,
      'updated': task.updatedAt,
    }));
    buf.writeln('---');
    buf.writeln();
    buf.writeln('# ${escapeMd(task.title)}');
    buf.writeln();
    buf.writeln('| Date       | Status | Notes |');
    buf.writeln('|------------|--------|-------|');

    final sortedLogs = [...task.logs]
      ..sort((a, b) => b.date.compareTo(a.date)); // newest first

    for (final log in sortedLogs) {
      final status = switch (log.status) {
        ParsedLogStatus.done => '✓',
        ParsedLogStatus.notDone => '✗',
        ParsedLogStatus.skipped => 'skip',
      };
      final note = log.note != null && log.note!.isNotEmpty
          ? escapeMd(log.note!)
          : (log.skipReason != null ? '(${escapeMd(log.skipReason!)})' : '');
      buf.writeln('| ${_fmtDate(log.date)} | $status | $note |');
    }
    buf.writeln();

    return buf.toString();
  }

  static ParsedTask parse(String content) {
    final delimiter = RegExp(r'^---\s*$', multiLine: true);
    final parts = content.split(delimiter);
    if (parts.length < 3) {
      throw FormatException('Task file missing frontmatter delimiters');
    }

    final meta = loadYaml(parts[1]) as YamlMap;
    final body = parts.sublist(2).join('---\n');

    final titleMatch = _headingRe.firstMatch(body);
    final title = titleMatch?.group(1)?.trim() ?? 'Untitled';

    final logs = _rowRe.allMatches(body).map((m) {
      final statusRaw = m.group(2);
      final status = switch (statusRaw) {
        '✓' => ParsedLogStatus.done,
        '✗' => ParsedLogStatus.notDone,
        'skip' => ParsedLogStatus.skipped,
        _ => ParsedLogStatus.notDone,
      };
      final noteRaw = m.group(3)!.trim();
      String? note;
      String? skipReason;
      if (status == ParsedLogStatus.skipped &&
          noteRaw.startsWith('(') &&
          noteRaw.endsWith(')')) {
        skipReason = noteRaw.substring(1, noteRaw.length - 1);
      } else if (noteRaw.isNotEmpty) {
        note = noteRaw;
      }
      return ParsedTaskLog(
        date: DateTime.parse(m.group(1)!),
        status: status,
        note: note,
        skipReason: skipReason,
      );
    }).toList();

    return ParsedTask(
      id: meta['id'] as String,
      title: title,
      displayOrder: meta['order'] as int? ?? 0,
      recurrence: meta['recurrence']?.toString(),
      tags: meta['tags'] != null
          ? List<String>.from(meta['tags'] as YamlList)
          : const [],
      reminders: meta['reminders'] != null
          ? List<String>.from(meta['reminders'] as YamlList)
          : const [],
      updatedAt: DateTime.parse(meta['updated'].toString()),
      logs: logs,
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
}
