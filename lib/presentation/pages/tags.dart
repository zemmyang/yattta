import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';

class TagsPage extends ConsumerStatefulWidget {
  final VoidCallback? onMenuPressed;

  const TagsPage({super.key, this.onMenuPressed});

  @override
  ConsumerState<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends ConsumerState<TagsPage> {
  final Set<int> _expandedIndices = {};

  @override
  Widget build(BuildContext context) {
    final tagsWithItemsAsync = ref.watch(tagsWithItemsProvider);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Tags'),
        prefixes: [
          if (widget.onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: widget.onMenuPressed!,
            ),
        ],
      ),
      child: tagsWithItemsAsync.when(
        data: (tagsWithItems) {
          if (tagsWithItems.isEmpty) {
            return Center(
              child: Text(
                'No tags found',
                style: FTheme.of(context).typography.sm.copyWith(color: FTheme.of(context).colors.mutedForeground),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FAccordion(
                control: FAccordionControl.lifted(
                  expanded: (index) => _expandedIndices.contains(index),
                  onChange: (index, expanded) => setState(() {
                    if (expanded) {
                      _expandedIndices.add(index);
                    } else {
                      _expandedIndices.remove(index);
                    }
                  }),
                ),
                children: tagsWithItems.asMap().entries.map((entry) {
                  final item = entry.value;
                  final totalItems = item.todos.length + item.tasks.length + item.trackers.length;

                  return FAccordionItem(
                    title: Row(
                      children: [
                        Expanded(child: Text('${item.tag.name} ($totalItems)')),
                        FButton.icon(
                          variant: FButtonVariant.ghost,
                          size: FButtonSizeVariant.sm,
                          onPress: () => _deleteTag(context, ref, item.tag),
                          child: const Icon(FLucideIcons.trash),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.todos.isNotEmpty) ...[
                          _buildSectionHeader(context, 'Todos'),
                          FTileGroup(
                            children: item.todos.map((t) => FTile(
                              title: Text(t.todo.title),
                              subtitle: Text(t.todo.status.name),
                            )).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (item.tasks.isNotEmpty) ...[
                          _buildSectionHeader(context, 'Tasks'),
                          FTileGroup(
                            children: item.tasks.map((t) => FTile(
                              title: Text(t.task.title),
                              subtitle: t.task.nextDueAt != null 
                                ? Text('Next: ${t.task.nextDueAt.toString().split(' ')[0]}') 
                                : null,
                            )).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (item.trackers.isNotEmpty) ...[
                          _buildSectionHeader(context, 'Trackers'),
                          FTileGroup(
                            children: item.trackers.map((t) => FTile(
                              title: Text(t.tracker.title),
                              subtitle: t.tracker.unit != null ? Text('Unit: ${t.tracker.unit}') : null,
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: FTheme.of(context).typography.xs.copyWith(
          fontWeight: FontWeight.bold,
          color: FTheme.of(context).colors.mutedForeground,
        ),
      ),
    );
  }

  void _deleteTag(BuildContext context, WidgetRef ref, Tag tag) async {
    final confirm = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('Delete Tag'),
        body: Text('Are you sure you want to move the tag "${tag.name}" to the recycle bin?'),
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
      await ref.read(tagsDaoProvider).softDelete(tag.id);
    }
  }
}
