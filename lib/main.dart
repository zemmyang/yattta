import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/utils/notification_service.dart';
import 'package:yattta/presentation/pages/sidebar.dart';
import 'package:yattta/presentation/pages/todos.dart';
import 'package:yattta/utils/theme_controller.dart';

final themeController = ThemeController();

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
      builder: (context, child) {
        // We use the platform dispatcher to get the brightness since MaterialApp isn't built yet.
        final platformBrightness = View.of(context).platformDispatcher.platformBrightness;
        final theme = themeController.getTheme(platformBrightness);

        return MaterialApp(
          supportedLocales: FLocalizations.supportedLocales,
          localizationsDelegates: const [...FLocalizations.localizationsDelegates],
          theme: theme.toApproximateMaterialTheme(),
          themeMode: themeController.themeMode,
          builder: (_, child) => FTheme(
            data: theme,
            child: FToaster(child: FTooltipGroup(child: child!)),
          ),
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Yattta'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.menu),
            onPress: () => showAppSidebar(context, themeController),
          ),
        ],
      ),
      child: const TodosPage(),
    );
  }
}
