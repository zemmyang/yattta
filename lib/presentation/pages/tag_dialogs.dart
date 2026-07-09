import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';

Future<String?> showAddTagDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final String? result = await showFDialog<String>(
    context: context,
    builder: (context, style, animation) => Consumer(
      builder: (context, ref, child) => StatefulBuilder(
        builder: (context, setState) {
          final tagsAsync = ref.watch(tagsStreamProvider);
          final deletedTagsAsync = ref.watch(deletedTagsProvider);
          final name = controller.text.trim();
          final existingTags = tagsAsync.value ?? [];
          final deletedTags = deletedTagsAsync.value ?? [];
          
          final isDuplicate = existingTags.any((t) => t.name.toLowerCase() == name.toLowerCase());
          final isDuplicateInDeleted = deletedTags.any((t) => t.name.toLowerCase() == name.toLowerCase());

          final suggestions = name.isEmpty
              ? <Tag>[]
              : [...existingTags, ...deletedTags]
                  .where((t) =>
                      t.name.toLowerCase().contains(name.toLowerCase()) && t.name.toLowerCase() != name.toLowerCase())
                  .toList();

          final colors = [
            '#EF4444', // Red
            '#F97316', // Orange
            '#F59E0B', // Amber
            '#10B981', // Emerald
            '#06B6D4', // Cyan
            '#3B82F6', // Blue
            '#6366F1', // Indigo
            '#8B5CF6', // Violet
            '#EC4899', // Pink
            '#71717A', // Zinc
          ];

          return FDialog(
            direction: Axis.horizontal,
            title: const Text('Add Tag'),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FTextField(
                  label: const Text('Tag Name'),
                  hint: 'Enter tag name',
                  control: FTextFieldControl.managed(
                    controller: controller,
                    onChange: (value) => setState(() {}),
                  ),
                  error: isDuplicate 
                      ? const Text('Tag already exists') 
                      : (isDuplicateInDeleted ? const Text('Tag exists in recycle bin') : null),
                ),
                const SizedBox(height: 16),
                Text(
                  'Color',
                  style: FTheme.of(context).typography.body.xs.copyWith(
                        color: FTheme.of(context).colors.mutedForeground,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((colorHex) {
                    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                    final isSelected = ref.read(_selectedColorProvider) == colorHex;
                    return GestureDetector(
                      onTap: () {
                        ref.read(_selectedColorProvider.notifier).state = colorHex;
                        setState(() {});
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: FTheme.of(context).colors.primary, width: 2)
                              : Border.all(color: Colors.transparent, width: 2),
                        ),
                        child: isSelected
                            ? Center(
                                child: Icon(
                                  FLucideIcons.check,
                                  size: 14,
                                  color: _getContrastColor(color),
                                ),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Suggestions',
                    style: FTheme.of(context).typography.body.xs.copyWith(
                          color: FTheme.of(context).colors.mutedForeground,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestions
                        .map((tag) => GestureDetector(
                              onTap: () => Navigator.of(context).pop(tag.id),
                              child: TagBadge(
                                tag: tag,
                                variant: FBadgeVariant.outline,
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
            actions: [
              FButton(
                onPress: () => Navigator.of(context).pop(),
                variant: FButtonVariant.ghost,
                child: const Text('Cancel'),
              ),
              FButton(
                onPress: (name.isEmpty || isDuplicate || isDuplicateInDeleted)
                    ? null
                    : () async {
                        final tagId = const Uuid().v4();
                        final selectedColor = ref.read(_selectedColorProvider);
                        await ref.read(tagsDaoProvider).upsert(TagsCompanion(
                              id: drift.Value(tagId),
                              name: drift.Value(name),
                              color: drift.Value(selectedColor),
                              createdAt: drift.Value(DateTime.now()),
                              updatedAt: drift.Value(DateTime.now()),
                            ));
                        if (context.mounted) {
                          Navigator.of(context).pop(tagId);
                        }
                      },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    ),
  );
  controller.dispose();
  return result;
}

Future<Set<String>?> showTagFilterDialog({
  required BuildContext context,
  required String title,
  required Set<String> initialSelectedTagIds,
  Widget? extraContent,
  VoidCallback? onReset,
}) async {
  return await showFDialog<Set<String>>(
    context: context,
    builder: (context, style, animation) => Consumer(
      builder: (context, ref, child) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final tagsAsync = ref.watch(tagsStreamProvider);
          final tags = tagsAsync.value ?? [];
          final selectedTagIds = {...initialSelectedTagIds};

          return FDialog(
            title: Text(title),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (extraContent != null) ...[
                  extraContent,
                  const SizedBox(height: 24),
                  Text(
                    'Filter by Tags',
                    style: FTheme.of(context).typography.body.sm.copyWith(
                          fontWeight: FontWeight.bold,
                          color: FTheme.of(context).colors.mutedForeground,
                        ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (tags.isEmpty)
                  Text(
                    'No tags available',
                    style: FTheme.of(context).typography.body.xs.copyWith(
                          color: FTheme.of(context).colors.mutedForeground,
                        ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final isSelected = selectedTagIds.contains(tag.id);
                      return GestureDetector(
                        onTap: () {
                          if (isSelected) {
                            selectedTagIds.remove(tag.id);
                          } else {
                            selectedTagIds.add(tag.id);
                          }
                          setStateDialog(() {});
                        },
                        child: TagBadge(
                          tag: tag,
                          variant: isSelected ? FBadgeVariant.secondary : FBadgeVariant.outline,
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
            actions: [
              FButton(
                variant: FButtonVariant.ghost,
                onPress: () {
                  if (onReset != null) {
                    onReset();
                  }
                  Navigator.of(context).pop(Set<String>.identity());
                },
                child: const Text('Reset'),
              ),
              FButton(
                onPress: () => Navigator.of(context).pop(selectedTagIds),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

final _selectedColorProvider = StateProvider<String?>((ref) => null);

Color _getContrastColor(Color color) {
  return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

class TagBadge extends StatelessWidget {
  final Tag tag;
  final FBadgeVariant variant;

  const TagBadge({
    super.key,
    required this.tag,
    this.variant = FBadgeVariant.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final tagColor = tag.color != null ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF'))) : null;

    return FBadge(
      variant: variant,
      style: tagColor != null
          ? FBadgeStyleDelta.delta(
              decoration: DecorationDelta.shapeDelta(
                color: variant == FBadgeVariant.outline ? tagColor.withValues(alpha: 0.1) : tagColor,
              ),
            )
          : const FBadgeStyleDelta.context(),
      child: Text(
        tag.name,
        style: tagColor != null
            ? TextStyle(
                color: variant == FBadgeVariant.outline ? tagColor : _getContrastColor(tagColor),
              )
            : null,
      ),
    );
  }
}
