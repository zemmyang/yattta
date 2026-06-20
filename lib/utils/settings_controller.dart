import 'package:flutter/foundation.dart';

final settingsController = SettingsController();

class SettingsController extends ChangeNotifier {
  int _timerDuration = 10;
  int _breakDuration = 5;
  int _longBreakDuration = 15;
  int _sessionsUntilLongBreak = 4;
  bool _autoStartBreaks = false;
  bool _autoStartWork = false;

  int get timerDuration => _timerDuration;
  int get breakDuration => _breakDuration;
  int get longBreakDuration => _longBreakDuration;
  int get sessionsUntilLongBreak => _sessionsUntilLongBreak;
  bool get autoStartBreaks => _autoStartBreaks;
  bool get autoStartWork => _autoStartWork;

  void setTimerDuration(int duration) {
    if (_timerDuration == duration) return;
    _timerDuration = duration;
    notifyListeners();
  }

  void setBreakDuration(int duration) {
    if (_breakDuration == duration) return;
    _breakDuration = duration;
    notifyListeners();
  }

  void setLongBreakDuration(int duration) {
    if (_longBreakDuration == duration) return;
    _longBreakDuration = duration;
    notifyListeners();
  }

  void setSessionsUntilLongBreak(int count) {
    if (_sessionsUntilLongBreak == count) return;
    _sessionsUntilLongBreak = count;
    notifyListeners();
  }

  void setAutoStartBreaks(bool value) {
    if (_autoStartBreaks == value) return;
    _autoStartBreaks = value;
    notifyListeners();
  }

  void setAutoStartWork(bool value) {
    if (_autoStartWork == value) return;
    _autoStartWork = value;
    notifyListeners();
  }
}
