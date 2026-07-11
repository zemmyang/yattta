import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/providers/sync_provider.dart';
import 'package:yattta/presentation/widgets/sync_overlay.dart';

class MockSyncController extends SyncController {
  final SyncState _initialState;
  MockSyncController(super.ref, this._initialState);

  @override
  SyncState get state => _initialState;

  @override
  void _setupAutoSync() {}

  @override
  Future<void> syncNow() async {}
}

void main() {
  Widget wrap(Widget child, List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: FTheme(
            data: FThemes.neutral.light.desktop,
            child: SyncOverlay(child: child),
          ),
        ),
      );

  testWidgets('SyncOverlay shows child when not syncing', (tester) async {
    await tester.pumpWidget(wrap(
      const Text('Main Content'),
      [
        syncControllerProvider.overrideWith((ref) => MockSyncController(ref, const SyncState(status: SyncStatus.idle))),
      ],
    ));

    expect(find.text('Main Content'), findsOneWidget);
    expect(find.text('Syncing...'), findsNothing);
  });

  testWidgets('SyncOverlay shows syncing indicator and progress', (tester) async {
    await tester.pumpWidget(wrap(
      const Text('Main Content'),
      [
        syncControllerProvider.overrideWith((ref) => MockSyncController(ref, const SyncState(status: SyncStatus.syncing))),
        syncProgressProvider.overrideWith((ref) => 'Downloading updates...'),
      ],
    ));

    expect(find.text('Main Content'), findsOneWidget);
    expect(find.text('Syncing...'), findsOneWidget);
    expect(find.text('Downloading updates...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SyncOverlay shows syncing indicator without progress message', (tester) async {
    await tester.pumpWidget(wrap(
      const Text('Main Content'),
      [
        syncControllerProvider.overrideWith((ref) => MockSyncController(ref, const SyncState(status: SyncStatus.syncing))),
        syncProgressProvider.overrideWith((ref) => null),
      ],
    ));

    expect(find.text('Syncing...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
