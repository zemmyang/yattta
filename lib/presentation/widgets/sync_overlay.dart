import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import '../providers/sync_provider.dart';

class SyncOverlay extends ConsumerWidget {
  final Widget child;

  const SyncOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncControllerProvider);
    final progress = ref.watch(syncProgressProvider);
    final isSyncing = syncState.status == SyncStatus.syncing;

    return Stack(
      children: [
        child,
        if (isSyncing)
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, opacity, child) {
                    return Opacity(
                      opacity: opacity,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: FTheme.of(context).colors.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: FTheme.of(context).colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Syncing...',
                                    style: FTheme.of(context).typography.body.sm.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (progress != null)
                                    Text(
                                      progress,
                                      style: FTheme.of(context).typography.body.xs.copyWith(
                                        color: FTheme.of(context).colors.mutedForeground,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
