// domain/sync/parsed_models.dart
//
// Pure Dart transfer objects produced by the markdown serializers and
// consumed by the sync engine when merging remote changes into Drift.
// No I/O, no Drift imports here on purpose — keeps domain/ clean.

enum ParsedPriority { low, normal, high }

class ParsedTodo {
  final String id;
  final String title;
  final bool completed;
  final DateTime? dueAt;
  final ParsedPriority priority;
  final List<String> tags;
  final DateTime updatedAt;

  ParsedTodo({
    required this.id,
    required this.title,
    required this.completed,
    required this.priority,
    required this.updatedAt,
    this.tags = const [],
    this.dueAt,
  });
}

enum ParsedLogStatus { done, notDone, skipped }

class ParsedTaskLog {
  final DateTime date;
  final ParsedLogStatus status;
  final String? note;
  final String? skipReason;

  ParsedTaskLog({
    required this.date,
    required this.status,
    this.note,
    this.skipReason,
  });
}

class ParsedTask {
  final String id;
  final String title;
  final int displayOrder;
  final String? recurrence; // raw recurrence string, e.g. "daily", "weekdays"
  final List<String> tags;
  final List<String> reminders; // "HH:mm" strings
  final DateTime updatedAt;
  final List<ParsedTaskLog> logs;

  ParsedTask({
    required this.id,
    required this.title,
    required this.displayOrder,
    required this.reminders,
    required this.updatedAt,
    required this.logs,
    this.tags = const [],
    this.recurrence,
  });
}

enum ParsedValueType { int, float }

enum ParsedGoalDirection { up, down }

class ParsedTrackerLog {
  final DateTime loggedAt;
  final double value;

  ParsedTrackerLog({required this.loggedAt, required this.value});
}

class ParsedTracker {
  final String id;
  final String name;
  final int displayOrder;
  final ParsedValueType valueType;
  final String unit;
  final ParsedGoalDirection goalDirection;
  final List<String> tags;
  final List<String> reminders;
  final DateTime updatedAt;
  final List<ParsedTrackerLog> logs;

  ParsedTracker({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.valueType,
    required this.unit,
    required this.goalDirection,
    required this.reminders,
    required this.updatedAt,
    required this.logs,
    this.tags = const [],
  });
}

class ParsedBrainDump {
  final String id;
  final String note;
  final bool isReviewed;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  ParsedBrainDump({
    required this.id,
    required this.note,
    required this.isReviewed,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });
}

class ParsedSetting {
  final String key;
  final String value;
  final DateTime updatedAt;

  ParsedSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
}
