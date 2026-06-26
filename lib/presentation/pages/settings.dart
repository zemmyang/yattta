import 'dart:io';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/utils/theme_controller.dart';
import 'package:yattta/utils/settings_controller.dart';
import 'package:yattta/utils/db_export.dart';

class SettingsPage extends StatefulWidget {
  final ThemeController themeController;

  const SettingsPage({super.key, required this.themeController});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _accordionKey = GlobalKey();
  final Set<int> _expandedIndices = {0, 1};

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Settings'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FAccordion(
            key: _accordionKey,
            control: FAccordionControl.lifted(
              expanded: (index) => _expandedIndices.contains(index),
              onChange: (index, expanded) => setState(() {
                if (expanded) {
                  _expandedIndices.add(index);
                } else {
                  _expandedIndices.remove(index);
                }
              }),
            ),
            children: [
              FAccordionItem(
                title: const Text('General'),
                child: ListenableBuilder(
                  listenable: settingsController,
                  builder: (context, _) => Column(
                    children: [
                      FSelect<UserMode>(
                        label: const Text('User Mode'),
                        description: const Text('Select the interface complexity'),
                        hint: 'Select mode',
                        items: const {
                          'Focused': UserMode.focused,
                          'Standard': UserMode.standard,
                          'Power User': UserMode.powerUser,
                        },
                        control: FSelectControl.lifted(
                          value: settingsController.userMode,
                          onChange: (value) {
                            if (value != null) {
                              settingsController.setUserMode(value);
                            }
                          },
                        ),
                      ),
                      if (settingsController.userMode != UserMode.focused) ...[
                        const SizedBox(height: 16),
                        FSelect<InitialPage>(
                          label: const Text('Initial Page'),
                          description: const Text('Select the page to show when opening the app'),
                          hint: 'Select page',
                          items: const {
                            'Todos': InitialPage.todos,
                            'Tasks': InitialPage.tasks,
                            'Trackers': InitialPage.trackers,
                          },
                          control: FSelectControl.lifted(
                            value: settingsController.initialPage,
                            onChange: (value) {
                              if (value != null) {
                                settingsController.setInitialPage(value);
                              }
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FSelect<int>(
                        label: const Text('Start of Week'),
                        description: const Text('Select the first day of the week'),
                        hint: 'Select day',
                        items: const {
                          'Monday': DateTime.monday,
                          'Tuesday': DateTime.tuesday,
                          'Wednesday': DateTime.wednesday,
                          'Thursday': DateTime.thursday,
                          'Friday': DateTime.friday,
                          'Saturday': DateTime.saturday,
                          'Sunday': DateTime.sunday,
                        },
                        control: FSelectControl.lifted(
                          value: settingsController.startOfWeek,
                          onChange: (value) {
                            if (value != null) {
                              settingsController.setStartOfWeek(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FAccordionItem(
                title: const Text('Appearance'),
                child: ListenableBuilder(
                  listenable: widget.themeController,
                  builder: (context, _) => Column(
                    children: [
                      FSelect<ThemeMode>(
                        label: const Text('Theme Mode'),
                        description: const Text('Select the application theme mode'),
                        hint: 'Select mode',
                        items: const {
                          'System Default': ThemeMode.system,
                          'Light': ThemeMode.light,
                          'Dark': ThemeMode.dark,
                        },
                        control: FSelectControl.lifted(
                          value: widget.themeController.themeMode,
                          onChange: (value) {
                            if (value != null) {
                              widget.themeController.setThemeMode(value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FSelect<String>(
                        label: const Text('Color Scheme'),
                        description: const Text('Select the application color scheme'),
                        hint: 'Select scheme',
                        items: const {
                          'Neutral': 'neutral',
                          'Zinc': 'zinc',
                          'Slate': 'slate',
                          'Blue': 'blue',
                          'Green': 'green',
                          'Orange': 'orange',
                          'Red': 'red',
                          'Rose': 'rose',
                          'Violet': 'violet',
                          'Yellow': 'yellow',
                        },
                        control: FSelectControl.lifted(
                          value: widget.themeController.scheme,
                          onChange: (value) {
                            if (value != null) {
                              widget.themeController.setScheme(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FAccordionItem(
                title: const Text('Timer'),
                child: ListenableBuilder(
                  listenable: settingsController,
                  builder: (context, _) => Column(
                    children: [
                      FTextField(
                        label: const Text('Work Duration (minutes)'),
                        description: const Text('Set the default timer duration for todos'),
                        keyboardType: TextInputType.number,
                        control: FTextFieldControl.managed(
                          initial: TextEditingValue(text: settingsController.timerDuration.toString()),
                          onChange: (value) {
                            final duration = int.tryParse(value.text);
                            if (duration != null) {
                              settingsController.setTimerDuration(duration);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FTextField(
                        label: const Text('Break Duration (minutes)'),
                        description: const Text('Set the default break duration'),
                        keyboardType: TextInputType.number,
                        control: FTextFieldControl.managed(
                          initial: TextEditingValue(text: settingsController.breakDuration.toString()),
                          onChange: (value) {
                            final duration = int.tryParse(value.text);
                            if (duration != null) {
                              settingsController.setBreakDuration(duration);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FTextField(
                        label: const Text('Long Break Duration (minutes)'),
                        description: const Text('Set the duration for long breaks'),
                        keyboardType: TextInputType.number,
                        control: FTextFieldControl.managed(
                          initial: TextEditingValue(text: settingsController.longBreakDuration.toString()),
                          onChange: (value) {
                            final duration = int.tryParse(value.text);
                            if (duration != null) {
                              settingsController.setLongBreakDuration(duration);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FTextField(
                        label: const Text('Sessions until Long Break'),
                        description: const Text('Number of work sessions before a long break'),
                        keyboardType: TextInputType.number,
                        control: FTextFieldControl.managed(
                          initial: TextEditingValue(text: settingsController.sessionsUntilLongBreak.toString()),
                          onChange: (value) {
                            final count = int.tryParse(value.text);
                            if (count != null) {
                              settingsController.setSessionsUntilLongBreak(count);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FSwitch(
                        label: const Text('Auto-start Breaks'),
                        description: const Text('Start break timers automatically after work'),
                        value: settingsController.autoStartBreaks,
                        onChange: (value) => settingsController.setAutoStartBreaks(value),
                      ),
                      const SizedBox(height: 16),
                      FSwitch(
                        label: const Text('Auto-start Work'),
                        description: const Text('Start work timers automatically after breaks'),
                        value: settingsController.autoStartWork,
                        onChange: (value) => settingsController.setAutoStartWork(value),
                      ),
                    ],
                  ),
                ),
              ),
              FAccordionItem(
                title: const Text('Data'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FTextField(
                      enabled: false,
                      label: const Text('Sync Server Address/IP'),
                      description: const Text('Server for multi-device synchronization (Coming soon)'),
                      hint: 'e.g. 192.168.1.100',
                    ),
                    const SizedBox(height: 16),
                    FButton(
                      child: const Text('Export Database'),
                      onPress: () async {
                        final result = await exportDatabase();
                        if (!context.mounted) return;

                        switch (result) {
                          case ExportResult.success:
                            showFToast(
                              context: context,
                              title: const Text('Database exported successfully'),
                            );
                          case ExportResult.notFound:
                            showFToast(
                              context: context,
                              title: const Text('No database found'),
                              description: const Text('Please create some data first.'),
                              variant: FToastVariant.destructive,
                            );
                          case ExportResult.error:
                            showFToast(
                              context: context,
                              title: const Text('Export failed'),
                              description: const Text('An error occurred while exporting.'),
                              variant: FToastVariant.destructive,
                            );
                          case ExportResult.webNotSupported:
                            showFToast(
                              context: context,
                              title: const Text('Data export is not available on web'),
                              variant: FToastVariant.destructive,
                            );
                          case ExportResult.cancelled:
                            // Do nothing if cancelled
                            break;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FButton(
                      variant: FButtonVariant.outline,
                      child: const Text('Reset Everything'),
                      onPress: () => showFDialog(
                        context: context,
                        builder: (context, style, animation) => FDialog(
                          animation: animation,
                          title: const Text('Reset Everything'),
                          body: const Text('This will delete ALL your data and reset all settings. This action cannot be undone. Are you sure?'),
                          actions: [
                            FButton(
                              variant: FButtonVariant.destructive,
                              child: const Text('Yes, Reset'),
                              onPress: () {
                                Navigator.of(context).pop();
                                showFDialog(
                                  context: context,
                                  builder: (context, style, animation) => FDialog(
                                    animation: animation,
                                    title: const Text('Final Confirmation'),
                                    body: const Text('ARE YOU ABSOLUTELY SURE? All your todos, tasks, and trackers will be PERMANENTLY DELETED.'),
                                    actions: [
                                      FButton(
                                        variant: FButtonVariant.destructive,
                                        child: const Text('PERMANENTLY DELETE'),
                                        onPress: () async {
                                          final navigator = Navigator.of(context);
                                          
                                          // 1. Reset settings first while DB is still open
                                          settingsController.reset();
                                          widget.themeController.reset();
                                          
                                          // 2. Small delay to let settings persist if needed
                                          await Future.delayed(const Duration(milliseconds: 100));
                                          
                                          // 3. Delete DB file (closes connection)
                                          await deleteDatabaseFile();
                                          
                                          if (context.mounted) {
                                            navigator.pop(); // Close dialog
                                            showFToast(
                                              context: context,
                                              title: const Text('App Reset'),
                                              description: const Text('The app will now close. Please restart it.'),
                                            );
                                            await Future.delayed(const Duration(seconds: 2));
                                            exit(0);
                                          }
                                        },
                                      ),
                                      FButton(
                                        variant: FButtonVariant.outline,
                                        child: const Text('Cancel'),
                                        onPress: () => Navigator.of(context).pop(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            FButton(
                              variant: FButtonVariant.outline,
                              child: const Text('Cancel'),
                              onPress: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
