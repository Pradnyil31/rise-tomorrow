import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;
import '../models/task.dart';
import '../config/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final fln.FlutterLocalNotificationsPlugin _plugin =
      fln.FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzData.initializeTimeZones();
    final dynamic val = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = (val is String) ? val : val.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const android = fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = fln.DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        fln.InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ─── Task Reminder ──────────────────────────────────────────────────────────
  
  static const _motivatingTitles = [
    'Time to crush it! 💪',
    'Your next win is waiting! 🚀',
    'Stay focused, you got this! 🎯',
    "Let's make it happen! ✨",
    'One step closer to your goals! 🏆',
    'Time to shine! 💫',
    'You are doing great, keep going! 🌟'
  ];

  Future<void> scheduleTaskReminder(Task task) async {
    if (task.dueDate == null) return;
    final notifyAt = task.dueDate!.subtract(const Duration(minutes: 15));
    if (notifyAt.isBefore(DateTime.now())) return;

    final title = _motivatingTitles[task.id.hashCode.abs() % _motivatingTitles.length];

    await _plugin.zonedSchedule(
      task.id.hashCode,
      title,
      'Time for: ${task.title}',
      tz.TZDateTime.from(notifyAt, tz.local),
      _taskDetails(),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await _plugin.cancel(taskId.hashCode);
  }

  // ─── Timer Complete ─────────────────────────────────────────────────────────

  Future<void> showTimerComplete({String title = 'Focus session complete! 🎉', String body = 'Great job! Take a well-deserved break.'}) async {
    await _plugin.show(
      9001,
      title,
      body,
      _timerDetails(),
    );
  }

  // ─── Daily Summary ──────────────────────────────────────────────────────────

  Future<void> scheduleDailySummary() async {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 20, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      8888,
      'Your Daily Summary 📊',
      'Check how productive you were today!',
      tz.TZDateTime.from(scheduled, tz.local),
      _summaryDetails(),
      androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: fln.DateTimeComponents.time,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─── Notification Details ───────────────────────────────────────────────────

  fln.NotificationDetails _taskDetails() => const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          AppConstants.notifChannelTaskId,
          'Task Reminders',
          channelDescription: 'Reminders for upcoming task due dates',
          importance: fln.Importance.high,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: fln.DarwinNotificationDetails(),
      );

  fln.NotificationDetails _timerDetails() => const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          AppConstants.notifChannelTimerId,
          'Timer Alerts',
          channelDescription: 'Alerts when focus sessions complete',
          importance: fln.Importance.max,
          priority: fln.Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: fln.DarwinNotificationDetails(),
      );

  fln.NotificationDetails _summaryDetails() => const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          AppConstants.notifChannelSummaryId,
          'Daily Summary',
          channelDescription: 'Daily productivity summary at 8 PM',
          importance: fln.Importance.defaultImportance,
          priority: fln.Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: fln.DarwinNotificationDetails(),
      );
}
