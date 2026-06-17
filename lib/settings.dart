import 'package:flutter/widgets.dart';
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
              return FTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Toggle between light and dark themes'),
                suffix: FSwitch(
                  value: themeController.isDark,
                  onChange: (value) => themeController.toggleTheme(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
