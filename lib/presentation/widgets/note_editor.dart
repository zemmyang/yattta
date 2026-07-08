import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:yattta/utils/settings_controller.dart';

class NoteEditor extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController textController;
  final QuillController quillController;
  final int maxLines;

  const NoteEditor({
    super.key,
    required this.label,
    required this.hint,
    required this.textController,
    required this.quillController,
    this.maxLines = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (settingsController.editorType == EditorType.wysiwyg) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FTheme.of(context).typography.body.sm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: FTheme.of(context).colors.mutedForeground,
                ),
          ),
          const SizedBox(height: 8),
          QuillSimpleToolbar(
            controller: quillController,
            config: const QuillSimpleToolbarConfig(
              showFontFamily: false,
              showFontSize: false,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: false,
              showStrikeThrough: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: true,
              showAlignmentButtons: false,
              showHeaderStyle: true,
              headerStyleType: HeaderStyleType.buttons,
              showListNumbers: false,
              showListBullets: false,
              showListCheck: true,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: true,
              showUndo: true,
              showRedo: true,
              showDirection: false,
              showSearchButton: false,
              showSubscript: true,
              showSuperscript: true,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: maxLines * 25.0,
            decoration: BoxDecoration(
              border: Border.all(color: FTheme.of(context).colors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(8),
            child: QuillEditor.basic(
              controller: quillController,
              config: QuillEditorConfig(
                placeholder: hint,
                spaceShortcutEvents: standardSpaceShorcutEvents,
              ),
            ),
          ),
        ],
      );
    } else {
      return FTextField(
        label: Text(label),
        hint: hint,
        maxLines: maxLines,
        control: FTextFieldControl.managed(controller: textController),
      );
    }
  }
}

Document loadNoteToDocument(String? text) {
  if (text == null || text.isEmpty) {
    return Document();
  }
  try {
    final List<dynamic> json = jsonDecode(text);
    return Document.fromJson(json);
  } catch (e) {
    return Document()..insert(0, text);
  }
}

String getNoteFromEditor(TextEditingController textController, QuillController quillController) {
  if (settingsController.editorType == EditorType.wysiwyg) {
    return jsonEncode(quillController.document.toDelta().toJson());
  } else {
    return textController.text.trim();
  }
}
