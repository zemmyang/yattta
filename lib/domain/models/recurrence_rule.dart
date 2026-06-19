// domain/models/recurrence_rule.dart
class RecurrenceRule {
  final String frequency; // 'daily', 'weekly', 'monthly', etc.
  final int interval;
  final List<String>? days;   // e.g. ['mon', 'wed', 'fri']
  final String? timeWindow;   // e.g. 'morning'
  final DateTime? endAt;

  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.days,
    this.timeWindow,
    this.endAt,
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) => RecurrenceRule(
    frequency:  json['frequency'] as String,
    interval:   json['interval']  as int? ?? 1,
    days:       (json['days'] as List?)?.cast<String>(),
    timeWindow: json['time_window'] as String?,
    endAt:      json['end_at'] != null
        ? DateTime.parse(json['end_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'frequency':   frequency,
    'interval':    interval,
    if (days       != null) 'days':        days,
    if (timeWindow != null) 'time_window': timeWindow,
    if (endAt      != null) 'end_at':      endAt!.toIso8601String(),
  };
}