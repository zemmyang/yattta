import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/widgets/log_accordion.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: FTheme(
          data: FThemes.neutral.light.desktop,
          child: Scaffold(body: child),
        ),
      );

  testWidgets('LogAccordion shows empty message when items is empty', (tester) async {
    await tester.pumpWidget(wrap(LogAccordion<String>(
      items: const [],
      getTimestamp: (_) => DateTime.now(),
      itemBuilder: (context, item) => Text(item),
      emptyMessage: 'No logs yet',
    )));

    expect(find.text('No logs yet'), findsOneWidget);
  });

  testWidgets('LogAccordion groups items by month', (tester) async {
    final now = DateTime(2024, 5, 20);
    final lastMonth = DateTime(2024, 4, 15);
    
    final items = [
      'Item 1 (May)',
      'Item 2 (May)',
      'Item 3 (April)',
    ];

    await tester.pumpWidget(wrap(LogAccordion<String>(
      items: items,
      getTimestamp: (item) {
        if (item.contains('May')) return now;
        return lastMonth;
      },
      itemBuilder: (context, item) => Text(item),
    )));

    // Check month headers
    expect(find.text('May 2024'), findsOneWidget);
    expect(find.text('April 2024'), findsOneWidget);

    // By default, the first group (May) should be expanded
    expect(find.text('Item 1 (May)'), findsOneWidget);
    expect(find.text('Item 2 (May)'), findsOneWidget);
    
    // Check that April group header is present
    expect(find.text('April 2024'), findsOneWidget);
  });

  testWidgets('LogAccordion renders all items and allows toggling', (tester) async {
    final now = DateTime(2024, 5, 20);
    final lastMonth = DateTime(2024, 4, 15);
    
    final items = [
      'Item 1 (May)',
      'Item 3 (April)',
    ];

    await tester.pumpWidget(wrap(LogAccordion<String>(
      items: items,
      getTimestamp: (item) {
        if (item.contains('May')) return now;
        return lastMonth;
      },
      itemBuilder: (context, item) => Text(item),
    )));

    expect(find.text('Item 1 (May)'), findsOneWidget);
    expect(find.text('Item 3 (April)'), findsOneWidget);

    // Tap on April 2024 header to ensure it's interactable
    await tester.tap(find.text('April 2024'));
    await tester.pumpAndSettle();
  });
}
