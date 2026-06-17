import 'package:flutter/foundation.dart';
import 'package:forui/forui.dart';

class ThemeController extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  FThemeData get theme {
    final isTouch = const <TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    }.contains(defaultTargetPlatform);

    if (_isDark) {
      return isTouch ? FThemes.neutral.dark.touch : FThemes.neutral.dark.desktop;
    } else {
      return isTouch ? FThemes.neutral.light.touch : FThemes.neutral.light.desktop;
    }
  }
}
