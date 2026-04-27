import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

/// Локальные уведомления: напоминание о приёме, действия «Принял» и «+15 мин».
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const int timerEndNotificationId = 91001;
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

  /// Запросить у Android 13+ уведомления и (где нужно) точные будильники — до zonedSchedule.
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
      // fullScreenIntent часто режется OEM/Android 14+ без роли «будильник» — оставляем обычный heads-up.
      fullScreenIntent: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('confirm', 'Принял', showsUserInterface: true),
        AndroidNotificationAction('snooze', '+15 мин', showsUserInterface: false),
      ],
    );

    const details = NotificationDetails(android: android);

    try {
      await _plugin.zonedSchedule(
        timerEndNotificationId,
        'Пора принять',
        medicationName,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'timer_end',
      );
    } catch (e, st) {
      debugPrint('zonedSchedule exact failed: $e\n$st');
      try {
        await _plugin.zonedSchedule(
          timerEndNotificationId,
          'Пора принять',
          medicationName,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'timer_end',
        );
      } catch (e2, st2) {
        debugPrint('zonedSchedule inexact failed: $e2\n$st2');
      }
    }

    if (kDebugMode) {
      debugPrint('Scheduled intake at $when (local wall was $whenLocal)');
    }
  }
}
