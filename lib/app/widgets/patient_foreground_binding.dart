import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import '../../features/auth/auth_session.dart';
import '../../features/timer/intake_timer_controller.dart';
import '../services/patient_foreground_task.dart';

/// На Android поднимает foreground service, пока пациент вошёл и есть расписание приёмов.
///
/// Снижает вероятность остановки процесса при свайпе из «Недавних»; не заменяет серверный worker.
class PatientForegroundBinding extends StatefulWidget {
  const PatientForegroundBinding({super.key, required this.child});

  final Widget child;

  @override
  State<PatientForegroundBinding> createState() => _PatientForegroundBindingState();
}

class _PatientForegroundBindingState extends State<PatientForegroundBinding> {
  bool _androidInited = false;
  String? _lastSyncKey;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'time2t3_foreground_v1',
          channelName: 'Приём лекарств (фон)',
          channelDescription: 'Сервис удерживает напоминания и проверку пропусков, пока есть расписание.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(180000),
          autoRunOnBoot: true,
          autoRunOnMyPackageReplaced: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      _androidInited = true;
    }
  }

  Future<void> _syncService(bool wantRunning) async {
    if (!_androidInited || !Platform.isAndroid) return;
    try {
      final running = await FlutterForegroundTask.isRunningService;
      if (!wantRunning) {
        if (running) {
          await FlutterForegroundTask.stopService();
        }
        return;
      }
      if (running) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Напоминания о приёме',
          notificationText: 'Работа в фоне: расписание и уведомления активны',
        );
        return;
      }
      await FlutterForegroundTask.startService(
        serviceId: 251001,
        serviceTypes: [ForegroundServiceTypes.dataSync],
        notificationTitle: 'Напоминания о приёме',
        notificationText: 'Работа в фоне: расписание и уведомления активны',
        callback: patientForegroundStartCallback,
      );
    } catch (e, st) {
      debugPrint('PatientForegroundBinding: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final timer = context.watch<IntakeTimerController>();
    final want = auth.isAuthenticated && auth.role == 'patient' && timer.hasAnySchedule;
    final key = '${auth.isAuthenticated}|${auth.role}|${timer.hasAnySchedule}|${timer.nextDueById.length}';
    if (key != _lastSyncKey) {
      _lastSyncKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_syncService(want));
      });
    }
    return widget.child;
  }
}
