import 'package:flutter/foundation.dart';
import '../data/database/app_database.dart';
import '../data/daos/settings_dao.dart';

final settingsController = SettingsController();

enum InitialPage { todos, tasks, trackers }

enum UserMode { focused, standard, powerUser }

class SettingsController extends ChangeNotifier {
  SettingsDao? _dao;

  int _timerDuration = 10;
  int _breakDuration = 5;
  int _longBreakDuration = 15;
  int _sessionsUntilLongBreak = 4;
  bool _autoStartBreaks = false;
  bool _autoStartWork = false;
  InitialPage _initialPage = InitialPage.todos;
  UserMode _userMode = UserMode.standard;
  int _startOfWeek = DateTime.monday;
  String _syncServerAddress = '';

  int get timerDuration => _timerDuration;
  int get breakDuration => _breakDuration;
  int get longBreakDuration => _longBreakDuration;
  int get sessionsUntilLongBreak => _sessionsUntilLongBreak;
  bool get autoStartBreaks => _autoStartBreaks;
  bool get autoStartWork => _autoStartWork;
  InitialPage get initialPage => _initialPage;
  UserMode get userMode => _userMode;
  int get startOfWeek => _startOfWeek;
  String get syncServerAddress => _syncServerAddress;

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
        orElse: () => UserMode.standard,
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

  Future<void> reset() async {
    await _dao?.deleteAll();
    _timerDuration = 10;
    _breakDuration = 5;
    _longBreakDuration = 15;
    _sessionsUntilLongBreak = 4;
    _autoStartBreaks = false;
    _autoStartWork = false;
    _initialPage = InitialPage.todos;
    _userMode = UserMode.standard;
    _startOfWeek = DateTime.monday;
    _syncServerAddress = '';
    notifyListeners();
  }
}
