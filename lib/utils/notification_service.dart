import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const LinuxInitializationSettings initializationSettingsLinux = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );

      // Windows requires a unique AUMID and a valid GUID in standard format.
      // Use uppercase and ensure it's a valid 8-4-4-4-12 pattern.
      const WindowsInitializationSettings initializationSettingsWindows = WindowsInitializationSettings(
        appName: 'Yattta',
        appUserModelId: 'Yattta.App.Timer',
        guid: '3F2E1B0A-4C5D-4E7F-A991-0C1E2B3D4F5A',
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
        linux: initializationSettingsLinux,
        windows: initializationSettingsWindows,
      );

      final initialized = await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap if needed
        },
      );
      
      if (kDebugMode) {
        print('NotificationService initialized: $initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing NotificationService: $e');
      }
      // We don't rethrow to avoid crashing the app on startup if notifications fail.
    }
  }

  Future<void> requestPermissions() async {
    try {
      if (kIsWeb) {
        final webImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>();
        await webImplementation?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting notification permissions: $e');
      }
    }
  }

  Future<void> showTimerFinishedNotification() async {
    try {
      const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        'timer_channel',
        'Timer Notifications',
        channelDescription: 'Notifications for timer completion',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
        windows: WindowsNotificationDetails(),
      );

      await _notificationsPlugin.show(
        id: 0,
        title: 'Timer Finished',
        body: 'Your 10-second timer has completed!',
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing notification: $e');
      }
    }
  }
}
