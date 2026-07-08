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
    builder: (context, style, animation) => StatefulBuilder(
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
  );
  controller.dispose();
  return result;
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
