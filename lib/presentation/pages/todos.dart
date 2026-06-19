import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class TodosPage extends StatelessWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Todos'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: const Center(
        child: Text('This is the Todos page'),
      ),
    );
  }
}
