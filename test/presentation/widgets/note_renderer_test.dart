import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/widgets/note_renderer.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: FTheme(
          data: FThemes.neutral.light.desktop,
          child: Scaffold(body: child),
        ),
      );

  testWidgets('NoteRenderer returns shrinked box for null or empty note', (tester) async {
    await tester.pumpWidget(wrap(const NoteRenderer(note: null)));
    expect(find.byType(SizedBox), findsOneWidget);
    
    await tester.pumpWidget(wrap(const NoteRenderer(note: '')));
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('NoteRenderer renders plain text', (tester) async {
    const text = 'Hello world';
    await tester.pumpWidget(wrap(const NoteRenderer(note: text)));

    expect(find.text(text), findsOneWidget);
  });

  testWidgets('NoteRenderer renders Quill JSON document', (tester) async {
    final doc = Document()..insert(0, 'Rich text content');
    final json = jsonEncode(doc.toDelta().toJson());

    await tester.pumpWidget(wrap(NoteRenderer(note: json)));

    // QuillEditor should be present
    expect(find.byType(QuillEditor), findsOneWidget);
    // It renders the text inside
    expect(find.textContaining('Rich text content', findRichText: true), findsOneWidget);
  });

  testWidgets('NoteRenderer in preview mode renders plain text even for JSON', (tester) async {
    final doc = Document()..insert(0, 'Rich text\nwith newlines');
    final json = jsonEncode(doc.toDelta().toJson());

    await tester.pumpWidget(wrap(NoteRenderer(note: json, isPreview: true)));

    // In preview mode, it should be a simple Text widget, not QuillEditor
    expect(find.byType(QuillEditor), findsNothing);
    expect(find.byType(Text), findsOneWidget);
    
    // It should replace newlines with spaces and trim
    expect(find.text('Rich text with newlines'), findsOneWidget);
  });

  testWidgets('NoteRenderer applies maxLines in preview mode', (tester) async {
    const text = 'A long text that should be truncated';
    await tester.pumpWidget(wrap(const NoteRenderer(
      note: text,
      isPreview: true,
      maxLines: 1,
    )));

    final textWidget = tester.widget<Text>(find.byType(Text));
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
