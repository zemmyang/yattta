import 'package:flutter/foundation.dart';

final settingsController = SettingsController();

class SettingsController extends ChangeNotifier {
  int _timerDuration = 10;

  int get timerDuration => _timerDuration;

  void setTimerDuration(int duration) {
    if (_timerDuration == duration) return;
    _timerDuration = duration;
    notifyListeners();
  }
}
