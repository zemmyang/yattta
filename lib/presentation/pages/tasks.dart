import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Tasks'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: const Center(
        child: Text('This is the Tasks page'),
      ),
    );
  }
}
