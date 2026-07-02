// data/sync/webdav/webdav_client.dart
//
// Thin wrapper around the webdav_plus package. Keeps the rest of the
// sync code from depending directly on webdav_plus types, so a future
// package swap only touches this file.

import 'dart:typed_data';

import 'package:webdav_plus/webdav_plus.dart';

class YatttaWebDavException implements Exception {
  final String message;
  final Object? cause;
  YatttaWebDavException(this.message, [this.cause]);

  @override
  String toString() => 'YatttaWebDavException: $message'
      '${cause != null ? ' ($cause)' : ''}';
}

class YatttaFile {
  final String path;
  final String name;
  final bool isDirectory;
  final DateTime? modified;

  YatttaFile({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.modified,
  });

  factory YatttaFile.fromResource(DavResource r) => YatttaFile(
    path: r.path,
    name: r.name,
    isDirectory: r.isDirectory,
    modified: r.modified,
  );
}

class YatttaWebDavClient {
  late final WebdavClient _client;

  YatttaWebDavClient({
    required String url,
    required String username,
    required String password,
  }) {
    _client = WebdavClient.withCredentials(
      username,
      password,
      baseUrl: url,
      isPreemptive: true, // avoids an extra round-trip on every request
    );
  }

  /// Creates the directory if it doesn't already exist. Safe to call
  /// repeatedly — checks existence first.
  Future<void> ensureDirectory(String path) async {
    try {
      final exists = await _client.exists(path);
      if (!exists) {
        await _client.createDirectory(path);
      }
    } catch (e) {
      throw YatttaWebDavException('Failed to ensure directory $path', e);
    }
  }

  /// Ensures the whole yattta folder tree exists. Call once on first
  /// sync setup, or defensively before any push.
  Future<void> ensureYatttaFolders() async {
    await ensureDirectory('/yattta/');
    await ensureDirectory('/yattta/tasks/');
    await ensureDirectory('/yattta/trackers/');
    await ensureDirectory('/yattta/journal/');
  }

  Future<void> write(String path, Uint8List bytes) async {
    try {
      await _client.put(path, bytes);
    } catch (e) {
      throw YatttaWebDavException('Failed to write $path', e);
    }
  }

  /// Returns null if the file doesn't exist (rather than throwing),
  /// since "not found" is an expected case on first sync.
  Future<Uint8List?> read(String path) async {
    try {
      return await _client.get(path);
    } on WebDAVNotFoundException {
      return null;
    } catch (e) {
      throw YatttaWebDavException('Failed to read $path', e);
    }
  }

  Future<List<YatttaFile>> list(String path) async {
    try {
      final resources = await _client.list(path);
      return resources.map(YatttaFile.fromResource).toList();
    } on WebDAVNotFoundException {
      return [];
    } catch (e) {
      throw YatttaWebDavException('Failed to list $path', e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _client.delete(path);
    } catch (e) {
      throw YatttaWebDavException('Failed to delete $path', e);
    }
  }

  Future<bool> exists(String path) async {
    try {
      return await _client.exists(path);
    } catch (e) {
      throw YatttaWebDavException('Failed to check existence of $path', e);
    }
  }

  /// RFC 6578 incremental sync. Pass null on first call.
  Future<List<YatttaFile>> syncCollection(
      String path,
      String syncToken,
      ) async {
    try {
      final resources = await _client.syncCollection(path, syncToken);
      return resources.map(YatttaFile.fromResource).toList();
    } catch (e) {
      throw YatttaWebDavException('syncCollection failed for $path', e);
    }
  }

  void dispose() {
    _client.shutdown();
  }
}
