import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/pages/tasks.dart';
import 'package:yattta/presentation/pages/todos.dart';
import 'package:yattta/presentation/pages/trackers.dart';
import 'package:yattta/presentation/pages/tags.dart';
import 'package:yattta/presentation/pages/brain_dumps.dart';
import 'package:yattta/presentation/pages/settings.dart';
import 'package:yattta/presentation/pages/statistics.dart';
import 'package:yattta/presentation/pages/recycle_bin.dart';
import 'package:yattta/presentation/pages/timers.dart';
import 'package:yattta/utils/theme_controller.dart';
import 'package:yattta/utils/settings_controller.dart';
import 'package:yattta/presentation/providers/sync_provider.dart';
import 'package:yattta/presentation/providers/sync_settings_provider.dart';

void showAppSidebar(BuildContext context, ThemeController themeController) {
  showFSheet(
    context: context,
    side: FLayout.ltr,
    builder: (context) => _AppSidebar(themeController: themeController),
  );
}

class _AppSidebar extends ConsumerWidget {
  final ThemeController themeController;

  const _AppSidebar({required this.themeController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncSettings = ref.watch(syncSettingsProvider);
    final syncState = ref.watch(syncControllerProvider);
    final isSyncing = syncState.status == SyncStatus.syncing;

    final items = [
      (
        icon: FLucideIcons.listTodo,
        label: 'Todos',
        builder: (context) => TodosPage(
              onMenuPressed: () => showAppSidebar(context, themeController),
            ),
        visible: true,
      ),
      (
        icon: FLucideIcons.clipboardList,
        label: 'Tasks',
        builder: (context) => TasksPage(
              onMenuPressed: () => showAppSidebar(context, themeController),
            ),
        visible: settingsController.userMode != UserMode.focused,
      ),
      (
        icon: FLucideIcons.activity,
        label: 'Trackers',
        builder: (context) => TrackersPage(
              onMenuPressed: () => showAppSidebar(context, themeController),
            ),
        visible: settingsController.userMode != UserMode.focused,
      ),
      (
        icon: FLucideIcons.tag,
        label: 'Tags',
        builder: (context) => TagsPage(
              onMenuPressed: () => showAppSidebar(context, themeController),
            ),
        visible: settingsController.userMode != UserMode.focused,
      ),
      (
        icon: FLucideIcons.timer,
        label: 'Timers',
        builder: (context) => TimersPage(
              onMenuPressed: () => showAppSidebar(context, themeController),
            ),
        visible: settingsController.userMode != UserMode.focused,
      ),
      (
        icon: FLucideIcons.brain,
        label: 'Brain Dumps',
        builder: (context) => BrainDumpsPage(
              onMenuPressed: () => showAppSidebar(context, themeController),
            ),
        visible: true,
      ),
      (
        icon: FLucideIcons.chartColumn,
        label: 'Statistics',
        builder: (context) => StatisticsPage(
              onMenuPressed: () => showAppSidebar(context, themeController),
            ),
        visible: settingsController.userMode == UserMode.powerUser,
      ),
      (
        icon: FLucideIcons.trash,
        label: 'Recycle Bin',
        builder: (context) => RecycleBinPage(
              onMenuPressed: () => showAppSidebar(context, themeController),
            ),
        visible: true,
      ),
      if (syncSettings.isConfigured)
        (
          icon: isSyncing ? FLucideIcons.loader : FLucideIcons.refreshCcw,
          label: isSyncing ? 'Syncing...' : 'Sync Now',
          builder: (context) => const SizedBox.shrink(), // Special case
          visible: true,
        ),
      (
        icon: FLucideIcons.settings,
        label: 'Settings',
        builder: (context) => SettingsPage(themeController: themeController),
        visible: true,
      ),
    ];

    return FSidebar(
      header: FHeader.nested(
        title: const Text('Menu'),
        suffixes: [
          FHeaderAction.x(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      children: items
          .where((item) => item.visible)
          .map(
            (item) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: FSidebarItem(
                icon: Icon(item.icon),
                label: Text(item.label),
                onPress: () {
                  if (item.label == 'Sync Now' || item.label == 'Syncing...') {
                    if (!isSyncing) {
                      ref.read(syncControllerProvider.notifier).syncNow();
                    }
                    return;
                  }

                  Navigator.of(context).pop(); // Close sidebar
                  if (item.label == 'Todos') {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: item.builder),
                      (route) => false,
                    );
                  } else if (item.label == 'Settings') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: item.builder),
                    );
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: item.builder),
                    );
                  }
                },
              ),
            ),
          )
          .toList(),
    );
  }
}
