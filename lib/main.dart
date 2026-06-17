import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/settings.dart';
import 'package:yattta/theme_controller.dart';

final themeController = ThemeController();

void main() {
  runApp(const Application());
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, child) {
        final theme = themeController.theme;
        return MaterialApp(
          supportedLocales: FLocalizations.supportedLocales,
          localizationsDelegates: const [...FLocalizations.localizationsDelegates],
          theme: theme.toApproximateMaterialTheme(),
          builder: (_, child) => FTheme(
            data: theme,
            child: FToaster(child: FTooltipGroup(child: child!)),
          ),
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openMenu(BuildContext context) {
    showFSheet(
      context: context,
      side: FLayout.ltr,
      builder: (context) => FSidebar(
        header: FHeader.nested(
          title: const Text('Menu'),
          suffixes: [
            FHeaderAction.x(onPress: () => Navigator.of(context).pop()),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FSidebarItem(
              icon: const Icon(FLucideIcons.settings),
              label: const Text('Settings'),
              onPress: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(themeController: themeController),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Yattta'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.menu),
            onPress: () => _openMenu(context),
          ),
        ],
      ),
      child: const Main(),
    );
  }
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  int _count = 0;
  int _timeLeft = 10;
  Timer? _timer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timeLeft = 10;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isPaused) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  void _togglePause() {
    if (_timer == null || !(_timer!.isActive) || _timeLeft <= 0) return;
    setState(() => _isPaused = !_isPaused);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Text('Count: $_count'),
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _timeLeft / 10,
                    strokeWidth: 3,
                    backgroundColor: FTheme.of(context).colors.border,
                    valueColor: AlwaysStoppedAnimation(FTheme.of(context).colors.primary),
                  ),
                  Text(
                    '$_timeLeft',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FButton(
                  onPress: () {
                    setState(() => _count++);
                    _startTimer();
                  },
                  suffix: const Icon(FLucideIcons.play),
                  child: const Text('Start'),
                ),
                const SizedBox(width: 10),
                FButton(
                  onPress: _togglePause,
                  suffix: Icon(_isPaused ? FLucideIcons.play : FLucideIcons.pause),
                  child: Text(_isPaused ? 'Resume' : 'Pause'),
                ),
              ],
            ),
          ],
        ),
      );
}
