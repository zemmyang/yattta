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

  bool isDueOn(DateTime date) {
    if (frequency == 'none') return false;

    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Check if after end date
    if (endAt != null && normalizedDate.isAfter(DateTime(endAt!.year, endAt!.month, endAt!.day))) {
      return false;
    }

    // Check if before start date
    if (startDate != null && normalizedDate.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) {
      return false;
    }

    // anchorDate for calculation
    final anchorDate = startDate != null
        ? DateTime(startDate!.year, startDate!.month, startDate!.day)
        : DateTime(1970, 1, 1);

    switch (frequency) {
      case 'daily':
        final diff = normalizedDate.difference(anchorDate).inDays;
        return diff >= 0 && diff % interval == 0;
      case 'weekly':
        if (weekDays != null && weekDays!.isNotEmpty) {
          // If weekdays are specified, check if today is one of them.
          // Note: interval might still apply to "every X weeks", but often it's ignored if specific days are set.
          // For simplicity, we match the days first.
          if (!weekDays!.contains(normalizedDate.weekday)) return false;

          // Now handle interval: find the start of the week for anchor and target
          final anchorWeekStart = anchorDate.subtract(Duration(days: anchorDate.weekday - 1));
          final targetWeekStart = normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
          final weeksDiff = targetWeekStart.difference(anchorWeekStart).inDays ~/ 7;
          return weeksDiff >= 0 && weeksDiff % interval == 0;
        }
        final diff = normalizedDate.difference(anchorDate).inDays;
        return diff >= 0 && (diff ~/ 7) % interval == 0 && normalizedDate.weekday == anchorDate.weekday;
      case 'monthly':
        if (normalizedDate.day != anchorDate.day) return false;
        final monthsDiff = (normalizedDate.year - anchorDate.year) * 12 + (normalizedDate.month - anchorDate.month);
        return monthsDiff >= 0 && monthsDiff % interval == 0;
      default:
        return false;
    }
  }
}
