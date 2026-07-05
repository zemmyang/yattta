import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/data/sync/serializers/tracker_file_serializer.dart';
import 'package:yattta/domain/sync/parsed_models.dart';

void main() {
  group('TrackerFileSerializer', () {
    final now = DateTime(2023, 10, 27, 10, 0);

    test('should serialize ParsedTracker to Markdown', () {
      final tracker = ParsedTracker(
        id: 'tracker-1',
        name: 'Weight',
        displayOrder: 2,
        valueType: ParsedValueType.float,
        unit: 'kg',
        goalDirection: ParsedGoalDirection.down,
        tags: ['health'],
        reminders: ['07:00'],
        updatedAt: now,
        logs: [
          ParsedTrackerLog(
            loggedAt: DateTime(2023, 10, 26, 7, 30),
            value: 75.5,
          ),
          ParsedTrackerLog(
            loggedAt: DateTime(2023, 10, 25, 7, 45),
            value: 76.2,
          ),
        ],
      );

      final output = TrackerFileSerializer.serialize(tracker);

      expect(output, contains('id: tracker-1'));
      expect(output, contains('order: 2'));
      expect(output, contains('type: float'));
      expect(output, contains('unit: kg'));
      expect(output, contains('goal: down'));
      expect(output, contains('tags: [health]'));
      expect(output, contains('reminders: ["07:00"]'));
      expect(output, contains('# Weight'));
      expect(output, contains('| 2023-10-26 07:30:00 | 75.5 |'));
      expect(output, contains('| 2023-10-25 07:45:00 | 76.2 |'));
    });

    test('should parse Markdown back to ParsedTracker', () {
      const content = '''---
id: tracker-1
order: 2
type: float
unit: kg
goal: down
tags:
  - health
reminders:
  - "07:00"
updated: 2023-10-27T10:00:00.000
---

# Weight

| Timestamp           | Value |
|---------------------|-------|
| 2023-10-26 07:30:15 | 75.5 |
| 2023-10-25 07:45:00 | 76.2 |
''';

      final result = TrackerFileSerializer.parse(content);

      expect(result.id, 'tracker-1');
      expect(result.name, 'Weight');
      expect(result.displayOrder, 2);
      expect(result.valueType, ParsedValueType.float);
      expect(result.unit, 'kg');
      expect(result.goalDirection, ParsedGoalDirection.down);
      expect(result.tags, contains('health'));
      expect(result.reminders, contains('07:00'));
      expect(result.logs.length, 2);

      expect(result.logs[0].loggedAt, DateTime(2023, 10, 26, 7, 30, 15));
      expect(result.logs[0].value, 75.5);

      expect(result.logs[1].loggedAt, DateTime(2023, 10, 25, 7, 45));
      expect(result.logs[1].value, 76.2);
    });

    test('should parse legacy Markdown (no seconds) back to ParsedTracker', () {
      const content = '''---
id: tracker-1
order: 2
type: float
unit: kg
goal: down
tags:
  - health
reminders:
  - "07:00"
updated: 2023-10-27T10:00:00.000
---

# Weight

| Timestamp        | Value |
|------------------|-------|
| 2023-10-26 07:30 | 75.5 |
''';

      final result = TrackerFileSerializer.parse(content);

      expect(result.logs.length, 1);
      expect(result.logs[0].loggedAt, DateTime(2023, 10, 26, 7, 30));
    });
  });
}
