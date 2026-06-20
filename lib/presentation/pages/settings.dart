import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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
            children: [
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
                        label: const Text('Countdown Duration (seconds)'),
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
                    ],
                  ),
                ),
              ),
              FAccordionItem(
                title: const Text('Data'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
