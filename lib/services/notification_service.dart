import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> showProgress(
      String id, String title, int progress) async {
    final androidDetails = AndroidNotificationDetails(
      'download_progress',
      'Download Progress',
      channelDescription: 'Shows download progress',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
    );
    await _plugin.show(
      id.hashCode,
      'Downloading: $title',
      '$progress%',
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showComplete(String id, String title) async {
    const androidDetails = AndroidNotificationDetails(
      'download_complete',
      'Download Complete',
      channelDescription: 'Notifies when download is complete',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      id.hashCode,
      'Download Complete',
      title,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showFailed(String id, String title) async {
    const androidDetails = AndroidNotificationDetails(
      'download_failed',
      'Download Failed',
      channelDescription: 'Notifies when download fails',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      id.hashCode,
      'Download Failed',
      title,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancel(String id) async {
    await _plugin.cancel(id.hashCode);
  }
}
