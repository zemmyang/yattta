import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/utils/notification_service.dart';
import 'package:yattta/presentation/pages/sidebar.dart';
import 'package:yattta/presentation/pages/todos.dart';
import 'package:yattta/utils/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
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
        builder: (context, child) => FTheme(
          data: themeController.getTheme(Theme.of(context).brightness),
          child: FToaster(child: FTooltipGroup(child: child!)),
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return TodosPage(
      onMenuPressed: () => showAppSidebar(context, themeController),
    );
  }
}
