import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/settings_controller.dart';

class SyncSettings {
  final String webdavUrl;
  final String webdavUser;
  final String webdavPassword;
  final int syncFrequency;
  final DateTime? lastSyncedAt;

  const SyncSettings({
    this.webdavUrl = '',
    this.webdavUser = '',
    this.webdavPassword = '',
    this.syncFrequency = 0,
    this.lastSyncedAt,
  });

  bool get isConfigured => webdavUrl.isNotEmpty && webdavUser.isNotEmpty && webdavPassword.isNotEmpty;

  SyncSettings copyWith({
    String? webdavUrl,
    String? webdavUser,
    String? webdavPassword,
    int? syncFrequency,
    DateTime? lastSyncedAt,
  }) {
    return SyncSettings(
      webdavUrl: webdavUrl ?? this.webdavUrl,
      webdavUser: webdavUser ?? this.webdavUser,
      webdavPassword: webdavPassword ?? this.webdavPassword,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class SyncSettingsNotifier extends StateNotifier<SyncSettings> {
  SyncSettingsNotifier() : super(const SyncSettings()) {
    _init();
  }

  void _init() {
    settingsController.addListener(_updateFromController);
    _updateFromController();
  }

  @override
  void dispose() {
    settingsController.removeListener(_updateFromController);
    super.dispose();
  }

  void _updateFromController() {
    state = state.copyWith(
      webdavUrl: settingsController.webDavServer,
      webdavUser: settingsController.webDavUsername,
      webdavPassword: settingsController.webDavPassword,
      syncFrequency: settingsController.syncFrequency,
    );
  }

  Future<void> markSynced() async {
    state = state.copyWith(lastSyncedAt: DateTime.now());
  }
}

final syncSettingsProvider = StateNotifierProvider<SyncSettingsNotifier, SyncSettings>((ref) {
  return SyncSettingsNotifier();
});
