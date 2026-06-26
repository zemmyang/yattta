// domain/models/recurrence_rule.dart
class RecurrenceRule {
  final String frequency; // 'none', 'daily', 'weekly', 'monthly'
  final int interval;
  final List<int>? weekDays; // 1 (Mon) to 7 (Sun)
  final DateTime? startDate;
  final DateTime? endAt;

  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.weekDays,
    this.startDate,
    this.endAt,
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) => RecurrenceRule(
        frequency: json['frequency'] as String? ?? 'none',
        interval: json['interval'] as int? ?? 1,
        weekDays: (json['weekDays'] as List?)?.cast<int>(),
        startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
        endAt: json['endAt'] != null ? DateTime.parse(json['endAt'] as String) : null,
      );

  Map<String, dynamic> toJson() => {
        'frequency': frequency,
        'interval': interval,
        if (weekDays != null) 'weekDays': weekDays,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endAt != null) 'endAt': endAt!.toIso8601String(),
      };

  @override
  String toString() {
    if (frequency == 'none') return 'None';
    final parts = <String>[];
    if (interval > 1) {
      parts.add('Every $interval ${frequency.replaceAll('ly', 's')}');
    } else {
      parts.add(frequency[0].toUpperCase() + frequency.substring(1));
    }

    if (frequency == 'weekly' && weekDays != null && weekDays!.isNotEmpty) {
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final selectedDays = weekDays!.map((d) => dayNames[d - 1]).join(', ');
      parts.add('on $selectedDays');
    }

    return parts.join(' ');
  }
}
