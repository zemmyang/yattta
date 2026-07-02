import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_providers.dart';

class SyncSettings {
  final String webdavUrl;
  final String webdavUser;
  final String webdavPassword;
  final DateTime? lastSyncedAt;

  const SyncSettings({
    this.webdavUrl = '',
    this.webdavUser = '',
    this.webdavPassword = '',
    this.lastSyncedAt,
  });

  bool get isConfigured => webdavUrl.isNotEmpty && webdavUser.isNotEmpty && webdavPassword.isNotEmpty;

  SyncSettings copyWith({
    String? webdavUrl,
    String? webdavUser,
    String? webdavPassword,
    DateTime? lastSyncedAt,
  }) {
    return SyncSettings(
      webdavUrl: webdavUrl ?? this.webdavUrl,
      webdavUser: webdavUser ?? this.webdavUser,
      webdavPassword: webdavPassword ?? this.webdavPassword,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class SyncSettingsNotifier extends StateNotifier<SyncSettings> {
  final Ref _ref;
  SyncSettingsNotifier(this._ref) : super(const SyncSettings()) {
    _load();
  }

  Future<void> _load() async {
    final dao = _ref.read(settingsDaoProvider);
    final url = await dao.getString('sync_webdav_url') ?? '';
    final user = await dao.getString('sync_webdav_user') ?? '';
    final pass = await dao.getString('sync_webdav_password') ?? '';
    final lastSyncStr = await dao.getString('sync_last_synced_at');
    final lastSync = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;

    state = SyncSettings(
      webdavUrl: url,
      webdavUser: user,
      webdavPassword: pass,
      lastSyncedAt: lastSync,
    );
  }

  Future<void> updateConfig({
    String? url,
    String? user,
    String? password,
  }) async {
    final dao = _ref.read(settingsDaoProvider);
    if (url != null) await dao.setString('sync_webdav_url', url);
    if (user != null) await dao.setString('sync_webdav_user', user);
    if (password != null) await dao.setString('sync_webdav_password', password);

    state = state.copyWith(
      webdavUrl: url,
      webdavUser: user,
      webdavPassword: password,
    );
  }

  Future<void> markSynced() async {
    final now = DateTime.now();
    await _ref.read(settingsDaoProvider).setString('sync_last_synced_at', now.toIso8601String());
    state = state.copyWith(lastSyncedAt: now);
  }
}

final syncSettingsProvider = StateNotifierProvider<SyncSettingsNotifier, SyncSettings>((ref) {
  return SyncSettingsNotifier(ref);
});
