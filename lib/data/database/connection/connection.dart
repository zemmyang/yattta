// data/database/connection/connection.dart
export 'unsupported.dart'
  if (dart.library.io) 'native.dart'
  if (dart.library.js_interop) 'web.dart';
