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

enum TimerMode { work, shortBreak, longBreak }

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  late int _timeLeft; // in seconds
  Timer? _timer;
  bool _isPaused = false;
  TimerMode _timerMode = TimerMode.work;
  int _sessionsCompleted = 0;

  int get _currentDurationMinutes {
    switch (_timerMode) {
      case TimerMode.work:
        return settingsController.timerDuration;
      case TimerMode.shortBreak:
        return settingsController.breakDuration;
      case TimerMode.longBreak:
        return settingsController.longBreakDuration;
    }
  }

  @override
  void initState() {
    super.initState();
    _timeLeft = _currentDurationMinutes * 60;
    settingsController.addListener(_onSettingsControllerChange);
  }

  void _onSettingsControllerChange() {
    if (_timer == null || !_timer!.isActive) {
      setState(() {
        _timeLeft = _currentDurationMinutes * 60;
      });
    }
  }

  void _startTimer() {
    NotificationService().requestPermissions();
    _timer?.cancel();
    setState(() {
      _timeLeft = _currentDurationMinutes * 60;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isPaused) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            _finishSession();
          }
        });
      }
    });
  }

  void _finishSession() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _isPaused = false;
      final finishedMode = _timerMode;
      String title;
      String body;
      bool shouldAutoStart = false;

      if (finishedMode == TimerMode.work) {
        _sessionsCompleted++;
        if (_sessionsCompleted % settingsController.sessionsUntilLongBreak == 0) {
          _timerMode = TimerMode.longBreak;
          title = 'Work Finished';
          body = 'Great job! Time for a long break. Ready for ${settingsController.longBreakDuration} minutes?';
        } else {
          _timerMode = TimerMode.shortBreak;
          title = 'Work Finished';
          body = 'Time for a break! Ready for ${settingsController.breakDuration} minutes?';
        }
        shouldAutoStart = settingsController.autoStartBreaks;
      } else {
        _timerMode = TimerMode.work;
        title = finishedMode == TimerMode.shortBreak ? 'Short Break Finished' : 'Long Break Finished';
        body = 'Break over! Ready to focus for ${settingsController.timerDuration} minutes?';
        shouldAutoStart = settingsController.autoStartWork;
      }

      _timeLeft = _currentDurationMinutes * 60;

      NotificationService().showTimerFinishedNotification(
        title: title,
        body: body,
      );

      if (shouldAutoStart) {
        _startTimer();
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

  String _getModeLabel() {
    switch (_timerMode) {
      case TimerMode.work:
        return 'WORK';
      case TimerMode.shortBreak:
        return 'SHORT BREAK';
      case TimerMode.longBreak:
        return 'LONG BREAK';
    }
  }

  Color _getTimerColor(BuildContext context) {
    switch (_timerMode) {
      case TimerMode.work:
        return FTheme.of(context).colors.primary;
      case TimerMode.shortBreak:
        return Colors.green;
      case TimerMode.longBreak:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth * 0.8
                  : constraints.maxHeight * 0.8)
              .clamp(0.0, 400.0);
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getModeLabel(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: size * 0.1,
                          color: _getTimerColor(context),
                        ),
                      ),
                      if (_timerMode == TimerMode.work) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Session ${(_sessionsCompleted % settingsController.sessionsUntilLongBreak) + 1} of ${settingsController.sessionsUntilLongBreak}',
                          style: TextStyle(
                            fontSize: size * 0.05,
                            color: FTheme.of(context).colors.mutedForeground,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: _timeLeft / (_currentDurationMinutes * 60),
                                strokeWidth: size * 0.05,
                                backgroundColor: FTheme.of(context).colors.border,
                                valueColor: AlwaysStoppedAnimation(_getTimerColor(context)),
                              ),
                            ),
                            Text(
                              '${(_timeLeft ~/ 60).toString().padLeft(2, '0')}:${(_timeLeft % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: size * 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_timer == null)
                        FButton(
                          onPress: _startTimer,
                          suffix: const Icon(FLucideIcons.play),
                          child: const Text('Start'),
                        )
                      else ...[
                        FButton(
                          onPress: _togglePause,
                          suffix: Icon(_isPaused ? FLucideIcons.play : FLucideIcons.pause),
                          child: Text(_isPaused ? 'Resume' : 'Pause'),
                        ),
                        const SizedBox(height: 10),
                        FButton(
                          variant: FButtonVariant.outline,
                          onPress: _finishSession,
                          suffix: const Icon(FLucideIcons.squareStop),
                          child: const Text('Stop'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}
