import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/providers/database_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:yattta/data/converters/enum_converters.dart';

class AddTrackerPage extends ConsumerStatefulWidget {
  const AddTrackerPage({super.key});

  @override
  ConsumerState<AddTrackerPage> createState() => _AddTrackerPageState();
}

class _AddTrackerPageState extends ConsumerState<AddTrackerPage> {
  final _titleController = TextEditingController();
  final _unitController = TextEditingController();
  TrackerValueType _valueType = TrackerValueType.integer;
  TrackerDirection _direction = TrackerDirection.increasing;

  @override
  void dispose() {
    _titleController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _saveTracker() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    final trackerId = const Uuid().v4();
    final trackersDao = ref.read(trackersDaoProvider);

    await trackersDao.upsert(TrackersCompanion(
      id: drift.Value(trackerId),
      title: drift.Value(title),
      unit: drift.Value(_unitController.text.trim().isEmpty ? null : _unitController.text.trim()),
      valueType: drift.Value(_valueType),
      direction: drift.Value(_direction),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Add Tracker'),
        prefixes: [
          FHeaderAction.x(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FTextField(
              label: const Text('Tracker Name'),
              hint: 'e.g. Weight, Daily Steps',
              control: FTextFieldControl.managed(controller: _titleController),
            ),
            const SizedBox(height: 24),
            FSelectGroup<TrackerValueType>(
              label: const Text('Value Type'),
              description: const Text('Should the tracked value be an integer or a decimal?'),
              control: FMultiValueControl.lifted(
                value: {_valueType},
                onChange: (values) {
                  if (values.isNotEmpty) {
                    setState(() => _valueType = values.first);
                  }
                },
              ),
              children: [
                FSelectGroupItemMixin.radio(
                  value: TrackerValueType.integer,
                  label: const Text('Integer'),
                ),
                FSelectGroupItemMixin.radio(
                  value: TrackerValueType.double,
                  label: const Text('Float'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FTextField(
              label: const Text('Units'),
              hint: 'e.g. kg, in, blank',
              control: FTextFieldControl.managed(controller: _unitController),
            ),
            const SizedBox(height: 24),
            FSelectGroup<TrackerDirection>(
              label: const Text('Goal Direction'),
              description: const Text('Do you want this number to be increasing or decreasing?'),
              control: FMultiValueControl.lifted(
                value: {_direction},
                onChange: (values) {
                  if (values.isNotEmpty) {
                    setState(() => _direction = values.first);
                  }
                },
              ),
              children: [
                FSelectGroupItemMixin.radio(
                  value: TrackerDirection.increasing,
                  label: const Text('Increasing'),
                ),
                FSelectGroupItemMixin.radio(
                  value: TrackerDirection.decreasing,
                  label: const Text('Decreasing'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: _saveTracker,
                child: const Text('Save Tracker'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
