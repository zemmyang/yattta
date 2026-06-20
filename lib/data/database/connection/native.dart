// data/database/connection/native.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

DatabaseConnection connect() {
  return DatabaseConnection.delayed(Future(() async {
    final dir  = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return DatabaseConnection(NativeDatabase.createInBackground(file));
  }));
}