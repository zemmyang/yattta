// domain/sync/sync_transport.dart
//
// Abstract contract for any sync backend (WebDAV today, possibly a
// FastAPI server later). presentation/providers/sync_provider.dart
// decides which implementation to hand out.

abstract class SyncTransport {
  /// Push all local changes to the remote store.
  Future<void> push();

  /// Pull remote changes and merge them into the local Drift DB.
  Future<void> pull();
}

/// Used when sync is disabled in settings.
class NoOpSyncEngine implements SyncTransport {
  const NoOpSyncEngine();

  @override
  Future<void> push() async {}

  @override
  Future<void> pull() async {}
}
