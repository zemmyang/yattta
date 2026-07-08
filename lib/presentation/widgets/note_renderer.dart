import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:forui/forui.dart';

class NoteRenderer extends StatelessWidget {
  final String? note;
  final bool isPreview;
  final int? maxLines;
  final TextStyle? style;

  const NoteRenderer({
    super.key,
    this.note,
    this.isPreview = false,
    this.maxLines,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (note == null || note!.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      final List<dynamic> json = jsonDecode(note!);
      final doc = Document.fromJson(json);

      if (isPreview) {
        return Text(
          doc.toPlainText().trim().replaceAll('\n', ' '),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style ?? FTheme.of(context).typography.body.sm,
        );
      }

      return QuillEditor.basic(
        controller: QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        ),
        config: const QuillEditorConfig(
          showCursor: false,
          enableInteractiveSelection: true,
        ),
      );
    } catch (e) {
      // Not JSON, treat as plain text/markdown
      return Text(
        note!.trim(),
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
        style: style ?? FTheme.of(context).typography.body.sm,
      );
    }
  }
}
