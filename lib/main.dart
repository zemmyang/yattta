import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/pages/tasks.dart';
import 'package:yattta/presentation/pages/trackers.dart';
import 'package:yattta/utils/notification_service.dart';
import 'package:yattta/presentation/pages/sidebar.dart';
import 'package:yattta/presentation/pages/todos.dart';
import 'package:yattta/utils/settings_controller.dart';
import 'package:yattta/utils/theme_controller.dart';
import 'package:yattta/data/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  
  await settingsController.initialize(db);
  await themeController.initialize(db);

  runApp(const Application());
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        supportedLocales: FLocalizations.supportedLocales,
        localizationsDelegates: const [...FLocalizations.localizationsDelegates],
        theme: themeController.getTheme(Brightness.light).toApproximateMaterialTheme(),
        darkTheme: themeController.getTheme(Brightness.dark).toApproximateMaterialTheme(),
        themeMode: themeController.themeMode,
        builder: (context, child) {
          final theme = themeController.getTheme(Theme.of(context).brightness);
          return FTheme(
            data: theme,
            child: FToaster(
              child: FTooltipGroup(
                child: ColoredBox(
                  color: theme.colors.background,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: child!,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        void onMenuPressed() => showAppSidebar(context, themeController);
        return switch (settingsController.initialPage) {
          InitialPage.todos => TodosPage(onMenuPressed: onMenuPressed),
          InitialPage.tasks => TasksPage(onMenuPressed: onMenuPressed),
          InitialPage.trackers => TrackersPage(onMenuPressed: onMenuPressed),
        };
      },
    );
  }
}
