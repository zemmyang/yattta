// data/database/connection/unsupported.dart
import 'package:drift/drift.dart';

DatabaseConnection connect() {
  throw UnsupportedError('No suitable database implementation found for this platform.');
}
