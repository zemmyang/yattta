// presentation/screens/settings/sync_settings_screen.dart
//
// Minimal functional screen — swap widgets for your custom design
// system components, this just wires the logic correctly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/webdav/webdav_client.dart';
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
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

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

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing connection...';
      _testSuccess = false;
    });

    try {
      // Temporarily create a client to test
      final client = YatttaWebDavClient(
        url: _urlController.text.trim(),
        username: _userController.text.trim(),
        password: _passwordController.text,
      );
      
      await client.ping();
      client.dispose();

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = 'Connection successful!';
          _testSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is YatttaWebDavException) {
          msg = e.friendlyMessage;
        }

        setState(() {
          _isTesting = false;
          _testResult = 'Connection failed: $msg';
          _testSuccess = false;
        });
      }
    }
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
        const SizedBox(height: 12),
        const Text('Sync Frequency'),
        DropdownButtonFormField<int>(
          initialValue: settings.syncFrequency,
          items: const [
            DropdownMenuItem(value: 0, child: Text('Manual Only')),
            DropdownMenuItem(value: 15, child: Text('Every 15 minutes')),
            DropdownMenuItem(value: 60, child: Text('Every hour')),
            DropdownMenuItem(value: 360, child: Text('Every 6 hours')),
            DropdownMenuItem(value: 720, child: Text('Every 12 hours')),
            DropdownMenuItem(value: 1440, child: Text('Daily')),
          ],
          onChanged: (value) {
            if (value != null) {
              settingsController.setSyncFrequency(value);
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _save, 
                child: const Text('Save'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _isTesting ? null : _testConnection,
                child: Text(_isTesting ? 'Testing...' : 'Test Connection'),
              ),
            ),
          ],
        ),
        if (_testResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _testResult!,
              style: TextStyle(
                color: _testSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
