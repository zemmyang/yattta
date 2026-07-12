import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:yattta/data/database/app_database.dart';
import 'package:yattta/presentation/pages/tag_dialogs.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: FTheme(
          data: FThemes.neutral.light.desktop,
          child: Scaffold(body: child),
        ),
      );

  testWidgets('TagBadge renders tag name', (tester) async {
    final tag = Tag(
      id: '1',
      name: 'Work',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(wrap(TagBadge(tag: tag)));

    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('TagBadge applies color correctly', (tester) async {
    // Red color
    final tag = Tag(
      id: '1',
      name: 'Urgent',
      color: '#EF4444',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(wrap(TagBadge(tag: tag)));

    // Check if the decoration color is applied (via style delta)
    // Note: FBadge style internals might be hard to probe directly without knowing forui implementation details,
    // but we can check if it renders.
    expect(find.text('Urgent'), findsOneWidget);
    
    // Verify text color for contrast (Red background should have white text)
    final text = tester.widget<Text>(find.text('Urgent'));
    expect(text.style?.color, Colors.white);
  });

  testWidgets('TagBadge applies outline variant color correctly', (tester) async {
    final tag = Tag(
      id: '1',
      name: 'Later',
      color: '#EF4444',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(wrap(TagBadge(
      tag: tag,
      variant: FBadgeVariant.outline,
    )));

    final text = tester.widget<Text>(find.text('Later'));
    // Outline variant should use the tag color for text
    expect(text.style?.color, const Color(0xFFEF4444));
  });
}
