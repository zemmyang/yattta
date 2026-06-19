import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/theme_controller.dart';

class SettingsPage extends StatelessWidget {
  final ThemeController themeController;

  const SettingsPage({super.key, required this.themeController});

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
          ListenableBuilder(
            listenable: themeController,
            builder: (context, child) {
              return Column(
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
                      value: themeController.themeMode,
                      onChange: (value) {
                        if (value != null) {
                          themeController.setThemeMode(value);
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
                      value: themeController.scheme,
                      onChange: (value) {
                        if (value != null) {
                          themeController.setScheme(value);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
