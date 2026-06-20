import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

final themeController = ThemeController();

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _scheme = 'neutral';

  ThemeMode get themeMode => _themeMode;
  String get scheme => _scheme;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setScheme(String scheme) {
    if (_scheme == scheme) return;
    _scheme = scheme;
    notifyListeners();
  }

  FThemeData getTheme(Brightness platformBrightness) {
    final isTouch = const <TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    }.contains(defaultTargetPlatform);

    final platformTheme = switch (_scheme) {
      'zinc' => FThemes.zinc,
      'slate' => FThemes.slate,
      'blue' => FThemes.blue,
      'green' => FThemes.green,
      'orange' => FThemes.orange,
      'red' => FThemes.red,
      'rose' => FThemes.rose,
      'violet' => FThemes.violet,
      'yellow' => FThemes.yellow,
      _ => FThemes.neutral,
    };

    final isDark = switch (_themeMode) {
      ThemeMode.system => platformBrightness == Brightness.dark,
      ThemeMode.light => false,
      ThemeMode.dark => true,
    };

    final modeTheme = isDark ? platformTheme.dark : platformTheme.light;
    return isTouch ? modeTheme.touch : modeTheme.desktop;
  }
}
