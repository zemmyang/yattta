import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import '../providers/database_providers.dart';
import 'unified_text_entry.dart';
import 'package:yattta/presentation/widgets/note_renderer.dart';


Future<void> showBrainDumpReviewDialog(BuildContext context, WidgetRef ref) async {
  await showFDialog(
    context: context,
    builder: (context, style, animation) => FDialog(
      title: const Text('Brain Dump Review'),
      body: Consumer(
        builder: (context, ref, child) {
          final brainDumpsAsync = ref.watch(unreviewedBrainDumpsProvider);
          final brainDumpsDao = ref.read(brainDumpsDaoProvider);

          return brainDumpsAsync.when(
            data: (notes) {
              if (notes.isEmpty) {
                return const Text('No new brain dumps to review.');
              }
              return SizedBox(
                height: 300,
                width: double.maxFinite,
                child: ListView.separated(
                  itemCount: notes.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return ListTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => UnifiedTextEntryPage.brainDump(brainDump: note)),
                      ),
                      title: NoteRenderer(
                        note: note.note,
                        isPreview: true,
                        maxLines: 2,
                      ),
                      subtitle: Text(
                        'Saved at: ${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                        style: FTheme.of(context).typography.body.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FButton.icon(
                            variant: FButtonVariant.ghost,
                            size: FButtonSizeVariant.sm,
                            onPress: () => brainDumpsDao.markAsReviewed(note.id),
                            child: const Icon(FLucideIcons.check),
                          ),
                          FButton.icon(
                            variant: FButtonVariant.ghost,
                            size: FButtonSizeVariant.sm,
                            onPress: () => brainDumpsDao.softDelete(note.id),
                            child: const Icon(FLucideIcons.trash),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error: $err'),
          );
        },
      ),
      actions: [
        FButton(
          onPress: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
