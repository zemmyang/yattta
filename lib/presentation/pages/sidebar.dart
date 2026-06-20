import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/pages/tasks.dart';
import 'package:yattta/presentation/pages/todos.dart';
import 'package:yattta/presentation/pages/trackers.dart';
import 'package:yattta/presentation/pages/settings.dart';
import 'package:yattta/utils/theme_controller.dart';

void showAppSidebar(BuildContext context, ThemeController themeController) {
  final items = [
    (
      icon: FLucideIcons.listTodo,
      label: 'Todos',
      builder: (context) => TodosPage(
            onMenuPressed: () => showAppSidebar(context, themeController),
          )
    ),
    (
      icon: FLucideIcons.clipboardList,
      label: 'Tasks',
      builder: (context) => TasksPage(
            onMenuPressed: () => showAppSidebar(context, themeController),
          )
    ),
    (
      icon: FLucideIcons.activity,
      label: 'Trackers',
      builder: (context) => TrackersPage(
            onMenuPressed: () => showAppSidebar(context, themeController),
          )
    ),
    (
      icon: FLucideIcons.settings,
      label: 'Settings',
      builder: (context) => SettingsPage(themeController: themeController)
    ),
  ];

  showFSheet(
    context: context,
    side: FLayout.ltr,
    builder: (context) => FSidebar(
      header: FHeader.nested(
        title: const Text('Menu'),
        suffixes: [
          FHeaderAction.x(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: FSidebarItem(
                icon: Icon(item.icon),
                label: Text(item.label),
                onPress: () {
                  Navigator.of(context).pop(); // Close sidebar
                  if (item.label == 'Todos') {
                    Navigator.of(context).popUntil((route) => route.isFirst);
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
    ),
  );
}
