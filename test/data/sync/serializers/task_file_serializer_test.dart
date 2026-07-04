import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/data/sync/serializers/task_file_serializer.dart';
import 'package:yattta/domain/sync/parsed_models.dart';

void main() {
  group('TaskFileSerializer', () {
    final now = DateTime(2023, 10, 27, 10, 0);

    test('should serialize ParsedTask to Markdown', () {
      final task = ParsedTask(
        id: 'task-1',
        title: 'Exercise',
        displayOrder: 1,
        tags: ['health', 'daily'],
        reminders: ['08:00'],
        updatedAt: now,
        recurrence: 'daily',
        logs: [
          ParsedTaskLog(
            date: DateTime(2023, 10, 26),
            status: ParsedLogStatus.done,
            note: 'Morning run',
          ),
          ParsedTaskLog(
            date: DateTime(2023, 10, 25),
            status: ParsedLogStatus.skipped,
            skipReason: 'Raining',
          ),
        ],
      );

      final output = TaskFileSerializer.serialize(task);

      expect(output, contains('id: task-1'));
      expect(output, contains('order: 1'));
      expect(output, contains('recurrence: daily'));
      expect(output, contains('tags: [health, daily]'));
      expect(output, contains('reminders: ["08:00"]'));
      expect(output, contains('# Exercise'));
      expect(output, contains('| 2023-10-26 | ✓ | Morning run |'));
      expect(output, contains('| 2023-10-25 | skip | (Raining) |'));
    });

    test('should parse Markdown back to ParsedTask', () {
      const content = '''---
id: task-1
order: 1
recurrence: daily
tags:
  - health
  - daily
reminders:
  - "08:00"
updated: 2023-10-27T10:00:00.000
---

# Exercise

| Date       | Status | Notes |
|------------|--------|-------|
| 2023-10-26 | ✓ | Morning run |
| 2023-10-25 | skip | (Raining) |
''';

      final result = TaskFileSerializer.parse(content);

      expect(result.id, 'task-1');
      expect(result.title, 'Exercise');
      expect(result.displayOrder, 1);
      expect(result.recurrence, 'daily');
      expect(result.tags, containsAll(['health', 'daily']));
      expect(result.reminders, contains('08:00'));
      expect(result.logs.length, 2);
      
      expect(result.logs[0].date, DateTime(2023, 10, 26));
      expect(result.logs[0].status, ParsedLogStatus.done);
      expect(result.logs[0].note, 'Morning run');

      expect(result.logs[1].date, DateTime(2023, 10, 25));
      expect(result.logs[1].status, ParsedLogStatus.skipped);
      expect(result.logs[1].skipReason, 'Raining');
    });
  });
}
