import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/domain/models/recurrence_rule.dart';

class ReminderData {
  final DateTime remindAt;
  final RecurrenceRule recurrenceRule;

  ReminderData({required this.remindAt, required this.recurrenceRule});
}

Future<ReminderData?> showAddReminderDialog(BuildContext context, {bool showRecurrence = true}) async {
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateTime.now());
  String selectedFrequency = 'none';

  return await showFDialog<ReminderData>(
    context: context,
    builder: (context, style, animation) {
      return StatefulBuilder(builder: (context, setState) {
        return FDialog(
          title: const Text('Add Reminder'),
          direction: Axis.vertical,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FButton(
                variant: FButtonVariant.outline,
                onPress: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => selectedDate = date);
                },
                child: Text('Date: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}'),
              ),
              const SizedBox(height: 8),
              FButton(
                variant: FButtonVariant.outline,
                onPress: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) setState(() => selectedTime = time);
                },
                child: Text('Time: ${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}'),
              ),
              if (showRecurrence) ...[
                const SizedBox(height: 16),
                FSelectGroup<String>(
                  label: const Text('Recurrence'),
                  control: FMultiValueControl.managedRadio(
                    initial: selectedFrequency,
                    onChange: (values) {
                      if (values.isNotEmpty) {
                        setState(() => selectedFrequency = values.first);
                      }
                    },
                  ),
                  children: [
                    FSelectGroupItemMixin.radio(value: 'none', label: const Text('None')),
                    FSelectGroupItemMixin.radio(value: 'daily', label: const Text('Daily')),
                    FSelectGroupItemMixin.radio(value: 'weekly', label: const Text('Weekly')),
                    FSelectGroupItemMixin.radio(value: 'monthly', label: const Text('Monthly')),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            FButton(
              onPress: () => Navigator.of(context).pop(),
              variant: FButtonVariant.ghost,
              child: const Text('Cancel'),
            ),
            FButton(
              onPress: () {
                final remindAt = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                Navigator.of(context).pop(ReminderData(
                  remindAt: remindAt,
                  recurrenceRule: RecurrenceRule(frequency: selectedFrequency),
                ));
              },
              child: const Text('Add'),
            ),
          ],
        );
      });
    },
  );
}
