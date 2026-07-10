import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/domain/models/recurrence_rule.dart';

void main() {
  group('RecurrenceRule.isDueOn', () {
    test('Daily recurrence', () {
      final rule = RecurrenceRule(
        frequency: 'daily',
        interval: 2,
        startDate: DateTime(2023, 10, 1),
      );

      expect(rule.isDueOn(DateTime(2023, 10, 1)), true);
      expect(rule.isDueOn(DateTime(2023, 10, 2)), false);
      expect(rule.isDueOn(DateTime(2023, 10, 3)), true);
      expect(rule.isDueOn(DateTime(2023, 10, 4)), false);
    });

    test('Weekly recurrence with weekDays', () {
      final rule = RecurrenceRule(
        frequency: 'weekly',
        interval: 1,
        weekDays: [1, 3, 5], // Mon, Wed, Fri
        startDate: DateTime(2023, 10, 1), // Sunday
      );

      expect(rule.isDueOn(DateTime(2023, 10, 2)), true); // Mon
      expect(rule.isDueOn(DateTime(2023, 10, 3)), false); // Tue
      expect(rule.isDueOn(DateTime(2023, 10, 4)), true); // Wed
      expect(rule.isDueOn(DateTime(2023, 10, 7)), false); // Sat
    });

    test('Weekly recurrence with interval 2', () {
       final rule = RecurrenceRule(
        frequency: 'weekly',
        interval: 2,
        weekDays: [1], // Monday
        startDate: DateTime(2023, 10, 2), // Monday (Week 1)
      );

      expect(rule.isDueOn(DateTime(2023, 10, 2)), true); // Mon Week 1
      expect(rule.isDueOn(DateTime(2023, 10, 9)), false); // Mon Week 2
      expect(rule.isDueOn(DateTime(2023, 10, 16)), true); // Mon Week 3
    });

    test('Monthly recurrence', () {
      final rule = RecurrenceRule(
        frequency: 'monthly',
        interval: 1,
        startDate: DateTime(2023, 10, 5),
      );

      expect(rule.isDueOn(DateTime(2023, 10, 5)), true);
      expect(rule.isDueOn(DateTime(2023, 11, 5)), true);
      expect(rule.isDueOn(DateTime(2023, 11, 6)), false);
      expect(rule.isDueOn(DateTime(2024, 10, 5)), true);
    });

    test('End date', () {
      final rule = RecurrenceRule(
        frequency: 'daily',
        startDate: DateTime(2023, 10, 1),
        endAt: DateTime(2023, 10, 5),
      );

      expect(rule.isDueOn(DateTime(2023, 10, 5)), true);
      expect(rule.isDueOn(DateTime(2023, 10, 6)), false);
    });
  });
}
