import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../data/database/app_database.dart';
import '../data/daos/settings_dao.dart';

final themeController = ThemeController();

class ThemeController extends ChangeNotifier {
  SettingsDao? _dao;

  ThemeMode _themeMode = ThemeMode.system;
  String _scheme = 'neutral';

  ThemeMode get themeMode => _themeMode;
  String get scheme => _scheme;

  Future<void> initialize(AppDatabase db) async {
    _dao = db.settingsDao;

    _scheme = await _dao!.getString('themeScheme') ?? _scheme;
    final modeStr = await _dao!.getString('themeMode');
    if (modeStr != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => ThemeMode.system,
      );
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _dao?.setString('themeMode', mode.name);
    notifyListeners();
  }

  void setScheme(String scheme) {
    if (_scheme == scheme) return;
    _scheme = scheme;
    _dao?.setString('themeScheme', scheme);
    notifyListeners();
  }

  void reset() {
    _themeMode = ThemeMode.system;
    _scheme = 'neutral';
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
