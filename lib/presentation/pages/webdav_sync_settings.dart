// presentation/screens/settings/sync_settings_screen.dart
//
// Minimal functional screen — swap widgets for your custom design
// system components, this just wires the logic correctly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_provider.dart';
import '../providers/sync_settings_provider.dart';
import '../../utils/settings_controller.dart';


class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() =>
      _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(syncSettingsProvider);
    _urlController = TextEditingController(text: settings.webdavUrl);
    _userController = TextEditingController(text: settings.webdavUser);
    _passwordController = TextEditingController(text: settings.webdavPassword);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _save() {
    settingsController.setWebDavServer(_urlController.text.trim());
    settingsController.setWebDavUsername(_userController.text.trim());
    settingsController.setWebDavPassword(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(syncSettingsProvider);
    final syncState = ref.watch(syncControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Nextcloud WebDAV URL'),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'https://cloud.example.com/remote.php/dav/files/you/',
          ),
        ),
        const SizedBox(height: 12),
        const Text('Username'),
        TextField(controller: _userController),
        const SizedBox(height: 12),
        const Text('Password / App password'),
        TextField(controller: _passwordController, obscureText: true),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
        const SizedBox(height: 24),
        if (settings.isConfigured) ...[
          if (settings.lastSyncedAt != null)
            Text('Last synced: ${settings.lastSyncedAt}'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: syncState.status == SyncStatus.syncing
                ? null
                : () => ref.read(syncControllerProvider.notifier).syncNow(),
            child: Text(
              syncState.status == SyncStatus.syncing
                  ? 'Syncing...'
                  : 'Sync now',
            ),
          ),
          if (syncState.status == SyncStatus.error)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sync failed: ${syncState.errorMessage}',
                style: const TextStyle(color: Color(0xFFCC0000)),
              ),
            ),
        ],
      ],
    );
  }
}
