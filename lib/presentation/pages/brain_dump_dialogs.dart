import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/database_providers.dart';
import '../../data/database/app_database.dart';
import 'tag_dialogs.dart';

Future<void> showBrainDumpDialog(BuildContext context, WidgetRef ref, {BrainDump? existingNote}) async {
  final controller = TextEditingController(text: existingNote?.note);
  final brainDumpsDao = ref.read(brainDumpsDaoProvider);
  final tagsDao = ref.read(tagsDaoProvider);

  final initialTags = existingNote != null ? await tagsDao.getTagsForBrainDump(existingNote.id) : <Tag>[];
  final selectedTagIds = initialTags.map((t) => t.id).toSet();

  if (!context.mounted) return;

  await showFDialog(
    context: context,
    builder: (context, style, animation) => StatefulBuilder(
      builder: (context, setState) {
        final tagsStream = ref.watch(tagsDaoProvider).watchAll();

        return FDialog(
          title: Text(existingNote == null ? 'Brain Dump' : 'Edit Brain Dump'),
          body: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FTextField(
                  label: const Text('Quick Note'),
                  hint: 'What\'s on your mind?',
                  maxLines: 5,
                  control: FTextFieldControl.managed(controller: controller),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tags (Optional)',
                      style: FTheme.of(context).typography.body.sm.copyWith(fontWeight: FontWeight.bold),
                    ),
                    FButton.icon(
                      variant: FButtonVariant.ghost,
                      size: FButtonSizeVariant.sm,
                      onPress: () async {
                        final tagId = await showAddTagDialog(context, ref);
                        if (tagId != null) {
                          setState(() {
                            selectedTagIds.add(tagId);
                          });
                        }
                      },
                      child: const Icon(FLucideIcons.plus),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<Tag>>(
                  stream: tagsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Text(
                        'No tags available',
                        style: FTheme.of(context).typography.body.xs.copyWith(color: FTheme.of(context).colors.mutedForeground),
                      );
                    }

                    final tags = snapshot.data!;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        final isSelected = selectedTagIds.contains(tag.id);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedTagIds.remove(tag.id);
                              } else {
                                selectedTagIds.add(tag.id);
                              }
                            });
                          },
                          child: TagBadge(
                            tag: tag,
                            variant: isSelected ? FBadgeVariant.primary : FBadgeVariant.outline,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
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
                  final brainDumpId = existingNote?.id ?? const Uuid().v4();
                  if (existingNote == null) {
                    await brainDumpsDao.insertBrainDump(BrainDumpsCompanion(
                      id: drift.Value(brainDumpId),
                      note: drift.Value(note),
                      createdAt: drift.Value(DateTime.now()),
                      updatedAt: drift.Value(DateTime.now()),
                    ));
                  } else {
                    await brainDumpsDao.updateBrainDump(
                      brainDumpId,
                      BrainDumpsCompanion(
                        note: drift.Value(note),
                        updatedAt: drift.Value(DateTime.now()),
                      ),
                    );
                    await tagsDao.detachAllFromBrainDump(brainDumpId);
                  }

                  for (final tagId in selectedTagIds) {
                    await tagsDao.attachToBrainDump(brainDumpId, tagId);
                  }
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(existingNote == null ? 'Save' : 'Update'),
            ),
          ],
        );
      },
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
