import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const int goalReachedNotificationId = 1001;
  static const int eatingWindowNotificationId = 1002;
  static const String _channelId = 'fast_oclock_alerts';
  static const String _channelName = 'Fasting Alerts';
  static const String _channelDesc =
      'Notifications for fasting goals and eating windows';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    try {
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (_) {
      // Safe no-op in headless test environments
    }
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        await ios.requestPermissions(alert: true, badge: true, sound: true);
      }
      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) {
        await macos.requestPermissions(alert: true, badge: true, sound: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleGoalReached({
    required int targetEndTimeUtcMs,
    required String protocolLabel,
  }) async {
    await cancelGoalReached();
    if (!_initialized) return;

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (targetEndTimeUtcMs <= nowMs) return;

    final scheduledDate = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.UTC,
      targetEndTimeUtcMs,
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        goalReachedNotificationId,
        'Fasting Goal Reached!',
        'You completed your $protocolLabel fasting target.',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> scheduleEatingWindowEnding({
    required int fastEndTimeUtcMs,
    required int targetDurationMin,
  }) async {
    await cancelEatingWindowEnding();
    if (!_initialized) return;
    if (targetDurationMin >= 1440) return; // Only for <24h protocols

    final eatingWindowMin = 1440 - targetDurationMin;
    final reminderUtcMs = fastEndTimeUtcMs + eatingWindowMin * 60000;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (reminderUtcMs <= nowMs) return;

    final scheduledDate = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.UTC,
      reminderUtcMs,
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        eatingWindowNotificationId,
        'Time to Start Your Next Fast',
        'Your eating window has ended. Ready to start your next fast?',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelGoalReached() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(goalReachedNotificationId);
    } catch (_) {}
  }

  Future<void> cancelEatingWindowEnding() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(eatingWindowNotificationId);
    } catch (_) {}
  }
}
