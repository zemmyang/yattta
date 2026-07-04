// data/sync/webdav/webdav_client.dart
//
// Thin wrapper around the webdav_plus package. Keeps the rest of the
// sync code from depending directly on webdav_plus types, so a future
// package swap only touches this file.

import 'package:flutter/foundation.dart';
import 'package:webdav_plus/webdav_plus.dart';

class YatttaWebDavException implements Exception {
  final String message;
  final Object? cause;
  YatttaWebDavException(this.message, [this.cause]);

  @override
  String toString() {
    if (kIsWeb && cause.toString().contains('Failed to fetch')) {
      return 'YatttaWebDavException: $message\n\n'
          '⚠️ Likely a CORS issue on the server.\n'
          'For WebDAV to work from a browser, your server must explicitly allow:\n'
          '1. Methods: PROPFIND, MKCOL, PUT, GET, DELETE, OPTIONS, REPORT\n'
          '2. Headers: Authorization, Content-Type, Depth, X-Requested-With\n'
          '3. Origins: Your app\'s domain\n'
          '4. Credentials: Allowed if using Basic Auth.';
    }
    return 'YatttaWebDavException: $message'
        '${cause != null ? ' ($cause)' : ''}';
  }

  String get friendlyMessage {
    final err = cause.toString().toLowerCase();

    if (err.contains('401')) {
      return 'Invalid username or password.';
    }
    if (err.contains('403')) {
      return 'Access denied. Please check your account permissions.';
    }
    if (err.contains('404')) {
      return 'Server folder not found. Please check your WebDAV URL.';
    }
    if (err.contains('405')) {
      return 'Server does not support a required operation.';
    }
    if (err.contains('412')) {
      return 'Conflict: File was changed elsewhere. Retrying...';
    }
    if (err.contains('502') || err.contains('503') || err.contains('504')) {
      return 'The server is currently unavailable or under maintenance.';
    }
    if (err.contains('timeout') || err.contains('deadline')) {
      return 'Connection timed out. Please check your internet.';
    }
    if (err.contains('socketexception') || err.contains('failed host lookup')) {
      return 'Could not connect to the server. Check your URL and internet.';
    }

    return message;
  }
}

class YatttaFile {
  final String path;
  final String name;
  final bool isDirectory;
  final DateTime? modified;
  final String? etag;

  YatttaFile({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.modified,
    this.etag,
  });

  factory YatttaFile.fromResource(DavResource r) => YatttaFile(
    path: r.path,
    name: r.name,
    isDirectory: r.isDirectory,
    modified: r.modified,
    etag: r.etag,
  );
}

class YatttaReadResult {
  final Uint8List bytes;
  final String? etag;
  YatttaReadResult(this.bytes, this.etag);
}

class YatttaWebDavClient {
  late final WebdavClient _client;
  late final String _basePath;

  YatttaWebDavClient({
    required String url,
    required String username,
    required String password,
  }) {
    // Crucial: baseUrl should ALWAYS end with / to avoid redirects
    // which cause CORS preflight failures in browsers.
    var baseUrl = url;
    if (!baseUrl.endsWith('/')) {
      baseUrl = '$baseUrl/';
    }

    // Extract the path portion of the URL to handle absolute paths
    // returned by some PROPFIND implementations.
    final uri = Uri.parse(baseUrl);
    _basePath = uri.path;

    _client = WebdavClient.withCredentials(
      username,
      password,
      baseUrl: baseUrl,
      isPreemptive: true,
    );
  }

  @visibleForTesting
  String normalize(String path, {bool isDirectory = false, bool stripTrailing = false}) =>
      _normalize(path, isDirectory: isDirectory, stripTrailing: stripTrailing);

  /// Most WebDAV servers prefer paths without a leading slash 
  /// when joined with a baseUrl that already ends in /.
  String _normalize(String path, {bool isDirectory = false, bool stripTrailing = false}) {
    var p = path;

    // If the server returned an absolute path (from root), strip the baseUrl path.
    if (p.startsWith(_basePath)) {
      p = p.substring(_basePath.length);
    }

    // Remove ALL leading slashes
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    // Directories must end with / for PROPFIND/LIST to avoid 301 redirects
    if (isDirectory && p.isNotEmpty && !p.endsWith('/')) {
      p = '$p/';
    }
    // Some servers fail MKCOL if a trailing slash is present
    if (stripTrailing && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// Creates the directory if it doesn't already exist.
  Future<void> ensureDirectory(String path) async {
    final p = _normalize(path, isDirectory: true);
    if (p.isEmpty) return;

    try {
      // 1. Check if it exists via PROPFIND (Depth 0)
      if (await _client.exists(p)) return;
      
      // 2. Fallback: try to list it. Some servers respond better to LIST.
      await _client.list(p);
      return;
    } catch (_) {
      // Likely doesn't exist.
    }

    // 3. Try to create it. We try with and without the trailing slash
    // because server behavior varies wildly here.
    final noSlash = _normalize(p, isDirectory: true, stripTrailing: true);
    try {
      await _client.createDirectory(noSlash);
    } catch (e) {
      final errorStr = e.toString();
      // 405/502/409 often mean it already exists or the proxy timed out
      // but the backend finished the creation.
      if (errorStr.contains('405') || errorStr.contains('502') || errorStr.contains('409')) {
        // Wait a beat for the server/proxy to stabilize
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          if (await _client.exists(p)) return;
          await _client.list(p);
          return;
        } catch (_) {}
      }
      
      // Last ditch effort: try MKCOL WITH trailing slash if without failed
      try {
        await _client.createDirectory(p);
      } catch (_) {
        // If both failed, we throw the original error or check one last time
        try {
          if (await _client.exists(p)) return;
        } catch (_) {}
        throw YatttaWebDavException('Failed to ensure directory $p', e);
      }
    }
  }

  /// Ensures the whole yattta folder tree exists.
  ///
  /// This is advisory — if it fails (e.g. 502 on MKCOL), we continue
  /// anyway and let the actual WRITE operations fail if the folders
  /// are truly missing.
  Future<void> ensureYatttaFolders() async {
    try {
      await ensureDirectory('yattta');
      await ensureDirectory('yattta/tasks');
      await ensureDirectory('yattta/trackers');
      await ensureDirectory('yattta/braindumps');
      await ensureDirectory('yattta/journal');
    } catch (e) {
      if (kDebugMode) {
        print('WebDAV: Advisory folder creation failed (continuing): $e');
      }
    }
  }

  Future<void> write(String path, Uint8List bytes, {String? ifMatch}) async {
    final p = _normalize(path);
    try {
      if (ifMatch != null) {
        await _client.putWithHeaders(p, bytes, {'If-Match': ifMatch});
      } else {
        await _client.put(p, bytes);
      }
    } catch (e) {
      throw YatttaWebDavException('Failed to write $p', e);
    }
  }

  /// Returns null if the file doesn't exist.
  Future<YatttaReadResult?> read(String path) async {
    final p = _normalize(path);
    try {
      // To get the ETag, we need to do a PROPFIND first.
      final resources = await _client.listWithDepth(p, 0);
      String? etag;
      if (resources.isNotEmpty) {
        etag = resources.first.etag;
      }
      
      final bytes = await _client.get(p);
      return YatttaReadResult(bytes, etag);
    } on WebDAVNotFoundException {
      return null;
    } catch (e) {
      final err = e.toString();
      if (err.contains('404')) return null;
      throw YatttaWebDavException('Failed to read $p', e);
    }
  }

  Future<YatttaFile?> getMetadata(String path) async {
    final p = _normalize(path);
    try {
      final resources = await _client.listWithDepth(p, 0);
      if (resources.isEmpty) return null;
      return YatttaFile.fromResource(resources.first);
    } catch (e) {
      if (e.toString().contains('404')) return null;
      return null;
    }
  }

  Future<List<YatttaFile>> list(String path) async {
    final p = _normalize(path, isDirectory: true);
    try {
      final resources = await _client.list(p);
      return resources.map(YatttaFile.fromResource).toList();
    } on WebDAVNotFoundException {
      return [];
    } catch (e) {
      if (e.toString().contains('404')) return [];
      throw YatttaWebDavException('Failed to list $p', e);
    }
  }

  Future<void> delete(String path, {bool isDirectory = false}) async {
    final p = _normalize(path, isDirectory: isDirectory);
    try {
      await _client.delete(p);
    } catch (e) {
      throw YatttaWebDavException('Failed to delete $p', e);
    }
  }

  Future<bool> exists(String path, {bool isDirectory = false}) async {
    final p = _normalize(path, isDirectory: isDirectory);
    try {
      return await _client.exists(p);
    } on WebDAVNotFoundException {
      return false;
    } catch (e) {
      if (e.toString().contains('404')) return false;
      throw YatttaWebDavException('Failed to check existence of $p', e);
    }
  }

  void dispose() {
    _client.shutdown();
  }

  /// Verifies if the server is reachable and credentials are correct.
  Future<void> ping() async {
    try {
      // PROPFIND on the base URL (Depth 0) is the standard way to 
      // check if a WebDAV endpoint is alive and authenticates.
      await _client.listWithDepth('', 0);
    } catch (e) {
      throw YatttaWebDavException('Server unreachable or invalid credentials', e);
    }
  }
}
