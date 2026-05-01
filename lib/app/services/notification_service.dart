import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

/// Локальные уведомления: напоминание о приёме, повтор через 15 мин, текст опекунам через 30 мин.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const int timerEndNotificationId = 91001;
  static const int patientRepeatNotificationId = 91002;
  static const int caregiverLocalNotificationId = 91003;
  static const String channelId = 'medication_timer_v1';

  void Function()? onConfirmFromNotification;
  void Function()? onSnoozeFromNotification;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final action = details.actionId ?? details.payload;
        if (action == 'confirm' || details.payload == 'confirm') {
          onConfirmFromNotification?.call();
        } else if (action == 'snooze' || details.payload == 'snooze') {
          onSnoozeFromNotification?.call();
        }
      },
    );

    const channel = AndroidNotificationChannel(
      channelId,
      'Напоминания о приёме',
      description: 'Таймер и подтверждение приёма',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _android?.createNotificationChannel(channel);
  }

  /// Запросить у Android 13+ уведомления и (где нужно) точные будильники - до zonedSchedule.
  Future<void> ensureAndroidSchedulePermissions() async {
    await _android?.requestNotificationsPermission();
    await _android?.requestExactAlarmsPermission();
    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> cancelTimerEnd() async {
    await _plugin.cancel(timerEndNotificationId);
    await _plugin.cancel(patientRepeatNotificationId);
    await _plugin.cancel(caregiverLocalNotificationId);
  }

  /// Локальное «настенное» время → момент в [tz.local] без двусмысленности UTC/Local.
  static tz.TZDateTime toTzLocal(DateTime localWallClock) {
    return tz.TZDateTime(
      tz.local,
      localWallClock.year,
      localWallClock.month,
      localWallClock.day,
      localWallClock.hour,
      localWallClock.minute,
      localWallClock.second,
      localWallClock.millisecond,
      localWallClock.microsecond,
    );
  }

  Future<void> _zonedScheduleOne({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e, st) {
      debugPrint('zonedSchedule exact failed (id=$id): $e\n$st');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (e2, st2) {
        debugPrint('zonedSchedule inexact failed (id=$id): $e2\n$st2');
      }
    }
  }

  Future<void> scheduleTimerEnd({
    required DateTime whenLocal,
    required String medicationName,
  }) async {
    await cancelTimerEnd();

    await ensureAndroidSchedulePermissions();

    final when = toTzLocal(whenLocal);

    const android = AndroidNotificationDetails(
      channelId,
      'Пора принять лекарство',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('confirm', 'Принял', showsUserInterface: true),
        AndroidNotificationAction('snooze', '+15 мин', showsUserInterface: false),
      ],
    );

    const details = NotificationDetails(android: android);

    await _zonedScheduleOne(
      id: timerEndNotificationId,
      title: 'Пора принять',
      body: medicationName,
      when: when,
      details: details,
      payload: 'timer_end',
    );

    if (kDebugMode) {
      debugPrint('Scheduled intake at $when (local wall was $whenLocal)');
    }
  }

  /// [anchorLocal] - момент первого уведомления «пора принять»: +15 мин повтор пациенту, +30 мин текст + API с телефона.
  Future<void> scheduleReminderEscalations({
    required DateTime anchorLocal,
    required String medicationName,
  }) async {
    await _plugin.cancel(patientRepeatNotificationId);
    await _plugin.cancel(caregiverLocalNotificationId);
    await ensureAndroidSchedulePermissions();

    final now = DateTime.now();
    final repeatAt = anchorLocal.add(const Duration(minutes: 15));
    final caregiverAt = anchorLocal.add(const Duration(minutes: 30));

    const androidWithActions = AndroidNotificationDetails(
      channelId,
      'Пора принять лекарство',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('confirm', 'Принял', showsUserInterface: true),
        AndroidNotificationAction('snooze', '+15 мин', showsUserInterface: false),
      ],
    );
    const detailsWithActions = NotificationDetails(android: androidWithActions);

    if (repeatAt.isAfter(now.add(const Duration(seconds: 2)))) {
      await _zonedScheduleOne(
        id: patientRepeatNotificationId,
        title: 'Напоминание о приёме',
        body: medicationName,
        when: toTzLocal(repeatAt),
        details: detailsWithActions,
        payload: 'timer_end',
      );
    }

    const androidInfo = AndroidNotificationDetails(
      channelId,
      'Уведомление опекуну',
      importance: Importance.high,
      priority: Priority.high,
    );
    const detailsInfo = NotificationDetails(android: androidInfo);

    if (caregiverAt.isAfter(now.add(const Duration(seconds: 2)))) {
      await _zonedScheduleOne(
        id: caregiverLocalNotificationId,
        title: 'Пропуск приёма',
        body:
            'Пациент не ответил на напоминания. Опекуны получают запись в приложении; при настройке SMTP - письмо на почту.',
        when: toTzLocal(caregiverAt),
        details: detailsInfo,
        payload: 'caregiver_escalation',
      );
    }
  }
}
