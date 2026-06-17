import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

void main() {
  runApp(Application());
}

class Application extends StatelessWidget {
  const Application({super.key});
  
  @override
  Widget build(BuildContext context) {
    /// Try changing this and hot reloading the application.
    ///
    /// To create a custom theme:
    /// ```shell
    /// dart forui theme create [theme template].
    /// ```
    final theme =
        const <TargetPlatform>{
          .android,
          .iOS,
          .fuchsia,
        }.contains(defaultTargetPlatform)
        ? FThemes.neutral.dark.touch
        : FThemes.neutral.dark.desktop;

    return MaterialApp(
      // TODO: replace with your application's supported locales.
      supportedLocales: FLocalizations.supportedLocales,
      // TODO: add your application's localizations delegates.
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      // MaterialApp's theme is also animated by default with the same duration and curve.
      // See https://api.flutter.dev/flutter/material/MaterialApp/themeAnimationStyle.html for how to configure this.
      //
      // There is a known issue with implicitly animated widgets where their transition occurs AFTER the theme's.
      // See https://github.com/duobaseio/forui/issues/670.
      theme: theme.toApproximateMaterialTheme(),
      builder: (_, child) => FTheme(
        data: theme,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
      // You can also replace FScaffold with Material Scaffold.
      home: const FScaffold(
        child: Example(),
      ),
    );
  }
}

class Example extends StatefulWidget {
  const Example({super.key});

  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  int _count = 0;
  int _timeLeft = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timeLeft = 10);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: .min,
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
        FButton(
          onPress: () {
            setState(() => _count++);
            _startTimer();
          },
          suffix: const Icon(FLucideIcons.play),
          child: const Text('Start'),
        ),
      ],
    ),
  );
}
