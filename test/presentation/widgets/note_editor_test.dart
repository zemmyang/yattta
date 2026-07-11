import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:yattta/presentation/widgets/note_editor.dart';
import 'package:yattta/utils/settings_controller.dart';

void main() {
  late TextEditingController textController;
  late QuillController quillController;

  setUp(() {
    textController = TextEditingController();
    quillController = QuillController.basic();
  });

  tearDown(() {
    textController.dispose();
    quillController.dispose();
  });

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

  testWidgets('NoteEditor renders plain text field when editorType is markdown', (tester) async {
    settingsController.setEditorType(EditorType.markdown);

    await tester.pumpWidget(wrap(NoteEditor(
      label: 'Note',
      hint: 'Enter note',
      textController: textController,
      quillController: quillController,
    )));

    expect(find.byType(FTextField), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.byType(QuillSimpleToolbar), findsNothing);
  });

  testWidgets('NoteEditor renders WYSIWYG editor when editorType is wysiwyg', (tester) async {
    settingsController.setEditorType(EditorType.wysiwyg);

    await tester.pumpWidget(wrap(NoteEditor(
      label: 'Note',
      hint: 'Enter note',
      textController: textController,
      quillController: quillController,
    )));

    expect(find.byType(QuillSimpleToolbar), findsOneWidget);
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
  });

  test('loadNoteToDocument handles null/empty', () {
    expect(loadNoteToDocument(null).isEmpty(), isTrue);
    expect(loadNoteToDocument('').isEmpty(), isTrue);
  });

  test('loadNoteToDocument handles plain text', () {
    final doc = loadNoteToDocument('Plain text');
    expect(doc.toPlainText().trim(), 'Plain text');
  });

  test('loadNoteToDocument handles JSON', () {
    final originalDoc = Document()..insert(0, 'Rich text');
    final json = jsonEncode(originalDoc.toDelta().toJson());
    
    final doc = loadNoteToDocument(json);
    expect(doc.toPlainText().trim(), 'Rich text');
  });

  test('getNoteFromEditor returns plain text for markdown editor', () {
    settingsController.setEditorType(EditorType.markdown);
    textController.text = 'Some text';
    
    final result = getNoteFromEditor(textController, quillController);
    expect(result, 'Some text');
  });

  test('getNoteFromEditor returns JSON for wysiwyg editor', () {
    settingsController.setEditorType(EditorType.wysiwyg);
    quillController.document.insert(0, 'Rich text');
    
    final result = getNoteFromEditor(textController, quillController);
    final decoded = jsonDecode(result);
    expect(decoded, isList);
  });
}
