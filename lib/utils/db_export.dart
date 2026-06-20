// utils/db_export.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportDatabase() async {
  if (kIsWeb) {
    _exportWeb();
  } else {
    await _exportNative();
  }
}

Future<void> _exportNative() async {
  final dir  = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'app.db'));
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/x-sqlite3')],
    subject: 'yattta database export',
  );
}

void _exportWeb() {
  // Web uses IndexedDB internally — there's no raw .db file to export.
  // The best option is to dump the data as JSON instead.
  throw UnimplementedError('Web export not yet implemented');
}
