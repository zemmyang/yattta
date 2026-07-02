import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/settings_controller.dart';

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
    state = SyncSettings(
      webdavUrl: settingsController.webDavServer,
      webdavUser: settingsController.webDavUsername,
      webdavPassword: settingsController.webDavPassword,
      // lastSyncedAt would need to be in settingsController too if we want to track it there
    );
  }

  Future<void> markSynced() async {
    // Optional: add lastSyncedAt to settingsController if needed
  }
}

final syncSettingsProvider = StateNotifierProvider<SyncSettingsNotifier, SyncSettings>((ref) {
  return SyncSettingsNotifier();
});
