import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class TrackersPage extends StatelessWidget {
  final VoidCallback? onMenuPressed;

  const TrackersPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Trackers'),
        prefixes: [
          if (onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: onMenuPressed!,
            ),
        ],
      ),
      child: const Center(
        child: Text('This is the Trackers page'),
      ),
    );
  }
}
