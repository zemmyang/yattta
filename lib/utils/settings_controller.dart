import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/database/app_database.dart';
import '../data/daos/settings_dao.dart';

final settingsController = SettingsController();

enum InitialPage { todos, tasks, trackers }

enum UserMode { focused, standard, powerUser }

enum EditorType { markdown, wysiwyg }

class SettingsController extends ChangeNotifier {
  SettingsDao? _dao;
  final _secureStorage = const FlutterSecureStorage();
  static const _webDavPasswordKey = 'webDavPassword';

  int _timerDuration = 10;
  int _breakDuration = 5;
  int _longBreakDuration = 15;
  int _sessionsUntilLongBreak = 4;
  bool _autoStartBreaks = false;
  bool _autoStartWork = false;
  InitialPage _initialPage = InitialPage.todos;
  UserMode _userMode = UserMode.focused;
  EditorType _editorType = EditorType.markdown;
  int _startOfWeek = DateTime.monday;
  String _syncServerAddress = '';
  bool _webDavEnabled = false;
  String _webDavServer = '';
  String _webDavUsername = '';
  String _webDavPassword = '';
  int _syncFrequency = 0; // 0 = manual, otherwise minutes

  int get timerDuration => _timerDuration;
  int get breakDuration => _breakDuration;
  int get longBreakDuration => _longBreakDuration;
  int get sessionsUntilLongBreak => _sessionsUntilLongBreak;
  bool get autoStartBreaks => _autoStartBreaks;
  bool get autoStartWork => _autoStartWork;
  InitialPage get initialPage => _initialPage;
  UserMode get userMode => _userMode;
  EditorType get editorType => _editorType;
  int get startOfWeek => _startOfWeek;
  String get syncServerAddress => _syncServerAddress;
  bool get webDavEnabled => _webDavEnabled;
  String get webDavServer => _webDavServer;
  String get webDavUsername => _webDavUsername;
  String get webDavPassword => _webDavPassword;
  int get syncFrequency => _syncFrequency;

  Future<void> initialize(AppDatabase db) async {
    _dao = db.settingsDao;

    _timerDuration = await _dao!.getInt('timerDuration') ?? _timerDuration;
    _breakDuration = await _dao!.getInt('breakDuration') ?? _breakDuration;
    _longBreakDuration = await _dao!.getInt('longBreakDuration') ?? _longBreakDuration;
    _sessionsUntilLongBreak = await _dao!.getInt('sessionsUntilLongBreak') ?? _sessionsUntilLongBreak;
    _autoStartBreaks = await _dao!.getBool('autoStartBreaks') ?? _autoStartBreaks;
    _autoStartWork = await _dao!.getBool('autoStartWork') ?? _autoStartWork;
    _startOfWeek = await _dao!.getInt('startOfWeek') ?? _startOfWeek;
    _syncServerAddress = await _dao!.getString('syncServerAddress') ?? _syncServerAddress;
    _webDavEnabled = await _dao!.getBool('webDavEnabled') ?? const bool.fromEnvironment('PRESEED_WEBDAV_ENABLED', defaultValue: false);
    _webDavServer = await _dao!.getString('webDavServer') ?? const String.fromEnvironment('PRESEED_WEBDAV_SERVER');
    _webDavUsername = await _dao!.getString('webDavUsername') ?? const String.fromEnvironment('PRESEED_WEBDAV_USERNAME');
    _syncFrequency = await _dao!.getInt('syncFrequency') ?? const int.fromEnvironment('PRESEED_WEBDAV_FREQUENCY', defaultValue: 0);
    
    // Load password from secure storage
    _webDavPassword = await _secureStorage.read(key: _webDavPasswordKey) ?? const String.fromEnvironment('PRESEED_WEBDAV_PASSWORD');

    // Migration from SQLite if needed
    final oldPassword = await _dao!.getString('webDavPassword');
    if (oldPassword != null && oldPassword.isNotEmpty) {
      if (_webDavPassword.isEmpty) {
        _webDavPassword = oldPassword;
        await _secureStorage.write(key: _webDavPasswordKey, value: _webDavPassword);
      }
      // Remove from SQLite after migration (or if it's already in secure storage)
      await (db.delete(db.settings)..where((t) => t.key.equals('webDavPassword'))).go();
    }

    final initialPageStr = await _dao!.getString('initialPage');
    if (initialPageStr != null) {
      _initialPage = InitialPage.values.firstWhere(
        (e) => e.name == initialPageStr,
        orElse: () => InitialPage.todos,
      );
    }

    final userModeStr = await _dao!.getString('userMode');
    if (userModeStr != null) {
      _userMode = UserMode.values.firstWhere(
        (e) => e.name == userModeStr,
        orElse: () => UserMode.focused,
      );
    }

    final editorTypeStr = await _dao!.getString('editorType');
    if (editorTypeStr != null) {
      _editorType = EditorType.values.firstWhere(
        (e) => e.name == editorTypeStr,
        orElse: () => EditorType.markdown,
      );
    }

    notifyListeners();
  }

  void setTimerDuration(int duration) {
    if (_timerDuration == duration) return;
    _timerDuration = duration;
    _dao?.setInt('timerDuration', duration);
    notifyListeners();
  }

  void setBreakDuration(int duration) {
    if (_breakDuration == duration) return;
    _breakDuration = duration;
    _dao?.setInt('breakDuration', duration);
    notifyListeners();
  }

  void setLongBreakDuration(int duration) {
    if (_longBreakDuration == duration) return;
    _longBreakDuration = duration;
    _dao?.setInt('longBreakDuration', duration);
    notifyListeners();
  }

  void setSessionsUntilLongBreak(int count) {
    if (_sessionsUntilLongBreak == count) return;
    _sessionsUntilLongBreak = count;
    _dao?.setInt('sessionsUntilLongBreak', count);
    notifyListeners();
  }

  void setAutoStartBreaks(bool value) {
    if (_autoStartBreaks == value) return;
    _autoStartBreaks = value;
    _dao?.setBool('autoStartBreaks', value);
    notifyListeners();
  }

  void setAutoStartWork(bool value) {
    if (_autoStartWork == value) return;
    _autoStartWork = value;
    _dao?.setBool('autoStartWork', value);
    notifyListeners();
  }

  void setInitialPage(InitialPage page) {
    if (_initialPage == page) return;
    _initialPage = page;
    _dao?.setString('initialPage', page.name);
    notifyListeners();
  }

  void setUserMode(UserMode mode) {
    if (_userMode == mode) return;
    _userMode = mode;
    _dao?.setString('userMode', mode.name);
    notifyListeners();
  }

  void setEditorType(EditorType type) {
    if (_editorType == type) return;
    _editorType = type;
    _dao?.setString('editorType', type.name);
    notifyListeners();
  }

  void setStartOfWeek(int day) {
    if (_startOfWeek == day) return;
    _startOfWeek = day;
    _dao?.setInt('startOfWeek', day);
    notifyListeners();
  }

  void setSyncServerAddress(String address) {
    if (_syncServerAddress == address) return;
    _syncServerAddress = address;
    _dao?.setString('syncServerAddress', address);
    notifyListeners();
  }

  void setWebDavEnabled(bool value) {
    if (_webDavEnabled == value) return;
    _webDavEnabled = value;
    _dao?.setBool('webDavEnabled', value);
    notifyListeners();
  }

  void setWebDavServer(String value) {
    if (_webDavServer == value) return;
    _webDavServer = value;
    _dao?.setString('webDavServer', value);
    notifyListeners();
  }

  void setWebDavUsername(String value) {
    if (_webDavUsername == value) return;
    _webDavUsername = value;
    _dao?.setString('webDavUsername', value);
    notifyListeners();
  }

  void setWebDavPassword(String value) {
    if (_webDavPassword == value) return;
    _webDavPassword = value;
    _secureStorage.write(key: _webDavPasswordKey, value: value);
    notifyListeners();
  }

  void setSyncFrequency(int minutes) {
    if (_syncFrequency == minutes) return;
    _syncFrequency = minutes;
    _dao?.setInt('syncFrequency', minutes);
    notifyListeners();
  }

  Future<void> reset() async {
    await _dao?.deleteAll();
    await _secureStorage.delete(key: _webDavPasswordKey);
    _timerDuration = 10;
    _breakDuration = 5;
    _longBreakDuration = 15;
    _sessionsUntilLongBreak = 4;
    _autoStartBreaks = false;
    _autoStartWork = false;
    _initialPage = InitialPage.todos;
    _userMode = UserMode.focused;
    _editorType = EditorType.markdown;
    _startOfWeek = DateTime.monday;
    _syncServerAddress = '';
    _webDavEnabled = false;
    _webDavServer = '';
    _webDavUsername = '';
    _webDavPassword = '';
    _syncFrequency = 0;
    notifyListeners();
  }
}
