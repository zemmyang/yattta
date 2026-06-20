// data/database/connection/web.dart
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

DatabaseConnection connect() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'app.db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return DatabaseConnection(result.resolvedExecutor);
  }));
}
