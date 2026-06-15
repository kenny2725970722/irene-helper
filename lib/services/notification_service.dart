import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Manages local push notifications for water & skincare reminders.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Call once at app startup.
  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Schedule hourly water reminders (8 AM to 10 PM).
  static Future<void> scheduleWaterReminders() async {
    await _cancelAll(waterId: true);

    for (int hour = 8; hour <= 22; hour++) {
      await _plugin.zonedSchedule(
        _waterId(hour),
        '💧 Time to drink water!',
        'Stay hydrated — grab a glass of water.',
        _nextTimeAt(hour, 0),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_channel',
            'Water Reminders',
            channelDescription: 'Hourly water drinking reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Schedule skincare mask reminders on Mon, Wed, Fri at 10 AM.
  static Future<void> scheduleSkincareReminders({int hour = 10, int minute = 0}) async {
    await _cancelAll(skincareId: true);

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    for (final dayOffset in [0, 2, 4]) {
      final maskDay = monday.add(Duration(days: dayOffset));
      final scheduledDate = DateTime(
        maskDay.year, maskDay.month, maskDay.day, hour, minute,
      );

      if (scheduledDate.isBefore(DateTime.now())) continue;

      await _plugin.zonedSchedule(
        _skincareId(dayOffset),
        '🧖 Skincare time!',
        'Apply your cleansing mask — self-care moment!',
        _toTZ(scheduledDate),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'skincare_channel',
            'Skincare Reminders',
            channelDescription: 'Cleansing mask reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelWaterReminders() async {
    await _cancelAll(waterId: true);
  }

  static Future<void> cancelSkincareReminders() async {
    await _cancelAll(skincareId: true);
  }

  // ── Helpers ──

  static int _waterId(int hour) => 1000 + hour;
  static int _skincareId(int dayOffset) => 2000 + dayOffset;

  static Future<void> _cancelAll({bool waterId = false, bool skincareId = false}) async {
    for (int h = 8; h <= 22 && waterId; h++) {
      await _plugin.cancel(_waterId(h));
    }
    for (int d = 0; d <= 4 && skincareId; d += 2) {
      await _plugin.cancel(_skincareId(d));
    }
  }

  static tz.TZDateTime _nextTimeAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _toTZ(DateTime dt) {
    return tz.TZDateTime.from(dt, tz.local);
  }
}
