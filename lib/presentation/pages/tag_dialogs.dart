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
    builder: (context, style, animation) => FDialog(
      direction: Axis.horizontal,
      title: const Text('Add Tag'),
      body: FTextField(
        label: const Text('Tag Name'),
        hint: 'Enter tag name',
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
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              final tagId = const Uuid().v4();
              await ref.read(tagsDaoProvider).upsert(TagsCompanion(
                    id: drift.Value(tagId),
                    name: drift.Value(name),
                    createdAt: drift.Value(DateTime.now()),
                    updatedAt: drift.Value(DateTime.now()),
                  ));
              if (context.mounted) {
                Navigator.of(context).pop(tagId);
              }
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
