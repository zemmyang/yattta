import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/database_providers.dart';
import '../../data/database/app_database.dart';

Future<void> showBrainDumpDialog(BuildContext context, WidgetRef ref, {BrainDump? existingNote}) async {
  final controller = TextEditingController(text: existingNote?.note);
  final brainDumpsDao = ref.read(brainDumpsDaoProvider);

  await showFDialog(
    context: context,
    builder: (context, style, animation) => FDialog(
      title: Text(existingNote == null ? 'Brain Dump' : 'Edit Brain Dump'),
      body: FTextField(
        label: const Text('Quick Note'),
        hint: 'What\'s on your mind?',
        maxLines: 5,
        control: FTextFieldControl.managed(controller: controller),
      ),
      actions: [
        FButton(
          onPress: () => Navigator.of(context).pop(),
          variant: FButtonVariant.ghost,
          child: const Text('Cancel'),
        ),
        FButton(
          onPress: () async {
            final note = controller.text.trim();
            if (note.isNotEmpty) {
              if (existingNote == null) {
                await brainDumpsDao.insertBrainDump(BrainDumpsCompanion(
                  id: drift.Value(const Uuid().v4()),
                  note: drift.Value(note),
                  createdAt: drift.Value(DateTime.now()),
                  updatedAt: drift.Value(DateTime.now()),
                ));
              } else {
                await brainDumpsDao.updateBrainDump(
                  existingNote.id,
                  BrainDumpsCompanion(
                    note: drift.Value(note),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );
              }
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Text(existingNote == null ? 'Save' : 'Update'),
        ),
      ],
    ),
  );
  controller.dispose();
}

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
                      onTap: () => showBrainDumpDialog(context, ref, existingNote: note),
                      title: Text(
                        note.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Saved at: ${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                        style: FTheme.of(context).typography.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
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
