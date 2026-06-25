import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'add_tracker.dart';

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
      child: Stack(
        children: [
          const Center(
            child: Text('This is the Trackers page'),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FButton.icon(
              onPress: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddTrackerPage()),
              ),
              child: const Icon(FLucideIcons.plus),
            ),
          ),
        ],
      ),
    );
  }
}
