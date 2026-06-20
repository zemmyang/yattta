import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class TasksPage extends StatelessWidget {
  final VoidCallback? onMenuPressed;

  const TasksPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Tasks'),
        prefixes: [
          if (onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: onMenuPressed!,
            ),
        ],
      ),
      child: const Center(
        child: Text('This is the Tasks page'),
      ),
    );
  }
}
