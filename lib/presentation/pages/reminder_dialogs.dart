import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/domain/models/recurrence_rule.dart';
import 'package:yattta/utils/settings_controller.dart';

class ReminderData {
  final DateTime remindAt;
  final RecurrenceRule recurrenceRule;

  ReminderData({required this.remindAt, required this.recurrenceRule});
}

Future<ReminderData?> showAddReminderDialog(BuildContext context, {bool showRecurrence = true}) async {
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateTime.now());
  String selectedFrequency = 'none';
  int selectedInterval = 1;
  final Set<int> selectedWeekDays = {};
  final intervalController = TextEditingController(text: '1');

  return await showFDialog<ReminderData>(
    context: context,
    builder: (context, style, animation) {
      return StatefulBuilder(builder: (context, setState) {
        final theme = FTheme.of(context);
        return FDialog(
          title: const Text('Add Reminder'),
          direction: Axis.vertical,
          body: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) setState(() => selectedDate = date);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FLucideIcons.calendar),
                      const SizedBox(width: 8),
                      Text('Date: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}'),
                    ],
                  ),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FLucideIcons.clock),
                      const SizedBox(width: 8),
                      Text('Time: ${selectedTime.format(context)}'),
                    ],
                  ),
                ),
                if (showRecurrence) ...[
                  const SizedBox(height: 24),
                  FSelectGroup<String>(
                    label: const Text('Frequency'),
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
                  if (selectedFrequency != 'none') ...[
                    const SizedBox(height: 16),
                    FTextField(
                      label: Text('Repeat every (in ${selectedFrequency == 'daily' ? 'days' : selectedFrequency.replaceAll('ly', 's')})'),
                      keyboardType: TextInputType.number,
                      control: FTextFieldControl.managed(
                        controller: intervalController,
                        onChange: (value) {
                          final interval = int.tryParse(value.text);
                          if (interval != null && interval > 0) {
                            selectedInterval = interval;
                          }
                        },
                      ),
                    ),
                    if (selectedFrequency == 'weekly') ...[
                      const SizedBox(height: 16),
                      Text('On weekdays', style: theme.typography.body.sm.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: List.generate(7, (index) {
                          final startOfWeek = settingsController.startOfWeek;
                          // index 0 -> startOfWeek, index 1 -> (startOfWeek % 7) + 1, etc.
                          final day = ((startOfWeek - 1 + index) % 7) + 1;
                          final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          final isSelected = selectedWeekDays.contains(day);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedWeekDays.remove(day);
                                } else {
                                  selectedWeekDays.add(day);
                                }
                              });
                            },
                            child: FBadge(
                              variant: isSelected ? FBadgeVariant.primary : FBadgeVariant.outline,
                              child: Text(dayNames[day - 1]),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ],
              ],
            ),
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
                  recurrenceRule: RecurrenceRule(
                    frequency: selectedFrequency,
                    interval: selectedInterval,
                    weekDays: selectedFrequency == 'weekly' ? (selectedWeekDays.toList()..sort()) : null,
                    startDate: remindAt,
                  ),
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
