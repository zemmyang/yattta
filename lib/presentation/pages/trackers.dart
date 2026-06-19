import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class TrackersPage extends StatelessWidget {
  const TrackersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Trackers'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: const Center(
        child: Text('This is the Trackers page'),
      ),
    );
  }
}
