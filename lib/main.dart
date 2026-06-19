import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/notification_service.dart';
import 'package:yattta/presentation/pages/tasks.dart';
import 'package:yattta/presentation/pages/todos.dart';
import 'package:yattta/presentation/pages/trackers.dart';
import 'package:yattta/presentation/pages/settings.dart';
import 'package:yattta/theme_controller.dart';

final themeController = ThemeController();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  runApp(const Application());
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, child) {
        // We use the platform dispatcher to get the brightness since MaterialApp isn't built yet.
        final platformBrightness = View.of(context).platformDispatcher.platformBrightness;
        final theme = themeController.getTheme(platformBrightness);

        return MaterialApp(
          supportedLocales: FLocalizations.supportedLocales,
          localizationsDelegates: const [...FLocalizations.localizationsDelegates],
          theme: theme.toApproximateMaterialTheme(),
          themeMode: themeController.themeMode,
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
    final items = [
      (icon: FLucideIcons.listTodo, label: 'Todos', builder: (context) => const TodosPage()),
      (icon: FLucideIcons.clipboardList, label: 'Tasks', builder: (context) => const TasksPage()),
      (icon: FLucideIcons.activity, label: 'Trackers', builder: (context) => const TrackersPage()),
      (
        icon: FLucideIcons.settings,
        label: 'Settings',
        builder: (context) => SettingsPage(themeController: themeController)
      ),
    ];

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
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: FSidebarItem(
                  icon: Icon(item.icon),
                  label: Text(item.label),
                  onPress: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: item.builder),
                    );
                  },
                ),
              ),
            )
            .toList(),
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
    NotificationService().requestPermissions();
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
            NotificationService().showTimerFinishedNotification();
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
