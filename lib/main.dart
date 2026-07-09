import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:yattta/l10n/app_localizations.dart';
import 'package:yattta/presentation/pages/tasks.dart';
import 'package:yattta/presentation/pages/trackers.dart';
import 'package:yattta/utils/notification_service.dart';
import 'package:yattta/presentation/pages/sidebar.dart';
import 'package:yattta/presentation/pages/todos.dart';
import 'package:yattta/utils/settings_controller.dart';
import 'package:yattta/utils/theme_controller.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/utils/seed_data.dart';
import 'package:yattta/presentation/providers/sync_provider.dart';
import 'package:yattta/presentation/widgets/sync_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  
  await settingsController.initialize(db);
  await themeController.initialize(db);

  if (const bool.fromEnvironment('PRESEED_DATA', defaultValue: false)) {
    final tags = await db.tagsDao.getAllTags();
    if (tags.isEmpty) {
      await DataSeeder(db).seed();
    }
  }

  runApp(const ProviderScope(child: Application()));
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          ...FLocalizations.localizationsDelegates,
          FlutterQuillLocalizations.delegate,
        ],
        theme: themeController.getTheme(Brightness.light).toApproximateMaterialTheme(),
        darkTheme: themeController.getTheme(Brightness.dark).toApproximateMaterialTheme(),
        themeMode: themeController.themeMode,
        builder: (context, child) {
          final theme = themeController.getTheme(Theme.of(context).brightness);
          return FTheme(
            data: theme,
            child: FToaster(
              child: FTooltipGroup(
                child: SyncOverlay(
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
            ),
          );
        },
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Global sync feedback
    ref.listen(syncControllerProvider, (previous, next) {
      final l10n = AppLocalizations.of(context)!;
      if (previous?.status == SyncStatus.syncing && next.status == SyncStatus.idle) {
        showFToast(context: context, title: Text(l10n.syncSuccessful));
      } else if (next.status == SyncStatus.error) {
        showFToast(
          context: context,
          title: Text(l10n.syncFailed),
          description: Text(next.errorMessage ?? l10n.unknownError),
          variant: FToastVariant.destructive,
        );
      }
    });

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
