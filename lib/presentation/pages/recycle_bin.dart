import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/providers/database_providers.dart';

class RecycleBinPage extends ConsumerWidget {
  final VoidCallback? onMenuPressed;

  const RecycleBinPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Recycle Bin'),
        prefixes: [
          if (onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: onMenuPressed!,
            ),
        ],
      ),
      child: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Todos'),
                Tab(text: 'Tasks'),
                Tab(text: 'Trackers'),
                Tab(text: 'Tags'),
                Tab(text: 'Brain Dumps'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _DeletedTodosList(),
                  _DeletedTasksList(),
                  _DeletedTrackersList(),
                  _DeletedTagsList(),
                  _DeletedBrainDumpsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletedTodosList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedTodosAsync = ref.watch(deletedTodosProvider);
    return deletedTodosAsync.when(
      data: (todos) => _buildList(
        context,
        todos.map((t) => _RecycleItem(
              title: t.title,
              onRestore: () => ref.read(todosDaoProvider).restore(t.id),
              onDelete: () => ref.read(todosDaoProvider).hardDelete(t.id),
            )).toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _DeletedTasksList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedTasksAsync = ref.watch(deletedTasksProvider);
    return deletedTasksAsync.when(
      data: (tasks) => _buildList(
        context,
        tasks.map((t) => _RecycleItem(
              title: t.title,
              onRestore: () => ref.read(tasksDaoProvider).restore(t.id),
              onDelete: () => ref.read(tasksDaoProvider).hardDelete(t.id),
            )).toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _DeletedTrackersList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedTrackersAsync = ref.watch(deletedTrackersProvider);
    return deletedTrackersAsync.when(
      data: (trackers) => _buildList(
        context,
        trackers.map((t) => _RecycleItem(
              title: t.title,
              onRestore: () => ref.read(trackersDaoProvider).restore(t.id),
              onDelete: () => ref.read(trackersDaoProvider).hardDelete(t.id),
            )).toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _DeletedTagsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedTagsAsync = ref.watch(deletedTagsProvider);
    return deletedTagsAsync.when(
      data: (tags) => _buildList(
        context,
        tags.map((t) => _RecycleItem(
              title: t.name,
              onRestore: () => ref.read(tagsDaoProvider).restore(t.id),
              onDelete: () => ref.read(tagsDaoProvider).hardDelete(t.id),
            )).toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _DeletedBrainDumpsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedBrainDumpsAsync = ref.watch(deletedBrainDumpsProvider);
    return deletedBrainDumpsAsync.when(
      data: (notes) => _buildList(
        context,
        notes.map((n) => _RecycleItem(
              title: n.note,
              onRestore: () => ref.read(brainDumpsDaoProvider).restore(n.id),
              onDelete: () => ref.read(brainDumpsDaoProvider).hardDelete(n.id),
            )).toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

Widget _buildList(BuildContext context, List<_RecycleItem> items) {
  if (items.isEmpty) {
    return const Center(child: Text('Recycle bin is empty.'));
  }
  return ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: items.length,
    separatorBuilder: (context, index) => const SizedBox(height: 8),
    itemBuilder: (context, index) => items[index],
  );
}

class _RecycleItem extends StatelessWidget {
  final String title;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _RecycleItem({
    required this.title,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FTile(
      title: Text(title),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: onRestore,
            child: const Icon(FLucideIcons.archiveRestore),
          ),
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: () => _confirmDelete(context),
            child: const Icon(FLucideIcons.trash),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirm = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('Permanent Delete'),
        body: Text('Are you sure you want to permanently delete "$title"? This action cannot be undone.'),
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
      onDelete();
    }
  }
}
