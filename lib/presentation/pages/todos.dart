import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:yattta/utils/notification_service.dart';
import 'package:yattta/utils/settings_controller.dart';

class TodosPage extends StatelessWidget {
  final VoidCallback? onMenuPressed;

  const TodosPage({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Todos'),
        prefixes: [
          if (onMenuPressed != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.menu),
              onPress: onMenuPressed!,
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
  late int _timeLeft;
  Timer? _timer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _timeLeft = settingsController.timerDuration;
    settingsController.addListener(_onSettingsControllerChange);
  }

  void _onSettingsControllerChange() {
    if (_timer == null || !_timer!.isActive) {
      setState(() {
        _timeLeft = settingsController.timerDuration;
      });
    }
  }

  void _startTimer() {
    NotificationService().requestPermissions();
    _timer?.cancel();
    setState(() {
      _timeLeft = settingsController.timerDuration;
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
    settingsController.removeListener(_onSettingsControllerChange);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth < constraints.maxHeight
              ? constraints.maxWidth * 0.8
              : constraints.maxHeight * 0.8;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _timeLeft / settingsController.timerDuration,
                          strokeWidth: size * 0.05,
                          backgroundColor: FTheme.of(context).colors.border,
                          valueColor: AlwaysStoppedAnimation(FTheme.of(context).colors.primary),
                        ),
                      ),
                      Text(
                        '$_timeLeft',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: size * 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FButton(
                      onPress: () {
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
        },
      );
}
