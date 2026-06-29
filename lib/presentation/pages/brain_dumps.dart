import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:yattta/presentation/pages/brain_dump_dialogs.dart';

class BrainDumpsPage extends ConsumerWidget {
  final VoidCallback? onMenuPressed;

  const BrainDumpsPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brainDumpsAsync = ref.watch(allBrainDumpsProvider);
    final brainDumpsDao = ref.read(brainDumpsDaoProvider);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Brain Dumps'),
        prefixes: [
          if (onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: onMenuPressed!,
            ),
        ],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => showBrainDumpDialog(context, ref),
          ),
        ],
      ),
      child: brainDumpsAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(child: Text('No brain dumps yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final note = notes[index];
              return FTile(
                title: Text(
                  note.note,
                  style: note.isReviewed
                      ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                      : null,
                ),
                subtitle: Text(
                  'Saved at: ${note.createdAt.year}-${note.createdAt.month.toString().padLeft(2, '0')}-${note.createdAt.day.toString().padLeft(2, '0')} ${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                  style: FTheme.of(context).typography.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
                ),
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!note.isReviewed)
                      FButton.icon(
                        variant: FButtonVariant.ghost,
                        size: FButtonSizeVariant.sm,
                        onPress: () => brainDumpsDao.markAsReviewed(note.id),
                        child: const Icon(FLucideIcons.check),
                      ),
                    FButton.icon(
                      variant: FButtonVariant.ghost,
                      size: FButtonSizeVariant.sm,
                      onPress: () => _deleteBrainDump(context, ref, note.id),
                      child: const Icon(FLucideIcons.trash),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _deleteBrainDump(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('Delete Brain Dump'),
        body: const Text('Are you sure you want to move this brain dump to the recycle bin?'),
        actions: [
          FButton(
            onPress: () => Navigator.of(context).pop(false),
            variant: FButtonVariant.ghost,
            child: const Text('Cancel'),
          ),
          FButton(
            onPress: () => Navigator.of(context).pop(true),
            variant: FButtonVariant.destructive,
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(brainDumpsDaoProvider).softDelete(id);
    }
  }
}
