// utils/db_export.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

enum ExportResult { success, cancelled, notFound, error, webNotSupported }

Future<ExportResult> exportDatabase() async {
  if (kIsWeb) {
    return ExportResult.webNotSupported;
  } else {
    return await _exportNative();
  }
}

Future<ExportResult> _exportNative() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));

    if (!await file.exists()) {
      return ExportResult.notFound;
    }

    final bytes = await file.readAsBytes();

    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Database Export',
      fileName: 'app_export.db',
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite', 'sqlite3'],
      bytes: bytes,
    );

    if (outputFile == null) {
      return ExportResult.cancelled;
    }

    return ExportResult.success;
  } catch (e) {
    debugPrint('Export error: $e');
    return ExportResult.error;
  }
}
