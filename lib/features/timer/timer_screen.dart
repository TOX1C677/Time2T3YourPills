import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_screen_layout.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/reminder_mode.dart';
import '../auth/auth_session.dart';
import '../medications/medications_controller.dart';
import 'intake_timer_controller.dart';

/// Временно скрыть зелёный статус «батарея не ограничивает» (проверка и кнопки выше остаются).
const bool _kUiShowBatteryOptimizationOkBanner = false;

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  /// null — ещё проверяем; true — уведомления разрешены; false — нет (показываем кнопку).
  bool? _notificationAllowed;
  bool _notificationNeedsSettings = false;

  /// Android: null — проверяем; true — не в списке оптимизации (или исключено).
  bool? _batteryOptimizationIgnored;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<IntakeTimerController>().refreshFromMedications();
      if (!mounted) return;
      await _refreshNotificationPermission();
      await _refreshBatteryOptimizationStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationPermission();
      _refreshBatteryOptimizationStatus();
    }
  }

  bool _notificationsEffectivelyAllowed(PermissionStatus status) {
    return status.isGranted || status.isProvisional;
  }

  Future<void> _refreshNotificationPermission() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      if (mounted) {
        setState(() {
          _notificationAllowed = true;
          _notificationNeedsSettings = false;
        });
      }
      return;
    }
    final status = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _notificationAllowed = _notificationsEffectivelyAllowed(status);
      _notificationNeedsSettings = status.isPermanentlyDenied || status.isRestricted;
    });
  }

  Future<void> _onRequestNotificationPermission() async {
    final before = await Permission.notification.status;
    if (!mounted) return;

    if (before.isPermanentlyDenied || before.isRestricted) {
      await openAppSettings();
      return;
    }

    final result = await Permission.notification.request();
    if (!mounted) return;

    setState(() {
      _notificationAllowed = _notificationsEffectivelyAllowed(result);
      _notificationNeedsSettings = result.isPermanentlyDenied || result.isRestricted;
    });

    if (Platform.isAndroid && (await Permission.scheduleExactAlarm.isDenied)) {
      await Permission.scheduleExactAlarm.request();
    }

    if (mounted) {
      await context.read<IntakeTimerController>().refreshFromMedications();
    }
  }

  Future<void> _refreshBatteryOptimizationStatus() async {
    if (!Platform.isAndroid) {
      if (mounted) setState(() => _batteryOptimizationIgnored = true);
      return;
    }
    try {
      final v = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (mounted) setState(() => _batteryOptimizationIgnored = v);
    } catch (_) {
      if (mounted) setState(() => _batteryOptimizationIgnored = false);
    }
  }

  Future<void> _onRequestIgnoreBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (_) {}
    if (!mounted) return;
    await _refreshBatteryOptimizationStatus();
    if (!mounted) return;
    if (_batteryOptimizationIgnored != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Если системное окно не появилось, нажмите «Настройки батареи» ниже и отключите оптимизацию для приложения.',
          ),
        ),
      );
    }
  }

  Future<void> _onOpenBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    } catch (_) {}
    if (!mounted) return;
    await _refreshBatteryOptimizationStatus();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$m:$s';
    }
    return '$m:$s';
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final intake = context.watch<IntakeTimerController>();
    final auth = context.watch<AuthSession>();
    context.watch<MedicationsController>();
    final showBatteryCard = Platform.isAndroid &&
        auth.isAuthenticated &&
        auth.role == 'patient' &&
        intake.hasMedications &&
        _batteryOptimizationIgnored != true;
    final outer = Theme.of(context);
    final theme = outer.copyWith(textTheme: AppTypography.timerScreenFrozen(outer.textTheme, layout));

    return Theme(
      data: theme,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Таймер'),
      ),
      body: ListView(
        padding: EdgeInsets.all(layout.spaceM),
        children: [
          if (_notificationAllowed == false) ...[
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: EdgeInsets.all(layout.spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _notificationNeedsSettings
                          ? 'Уведомления отключены в настройках. Включите их, чтобы приходили напоминания о приёме.'
                          : 'Без разрешения на уведомления напоминания о приёме не будут показываться.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onErrorContainer),
                    ),
                    SizedBox(height: layout.spaceM),
                    FilledButton(
                      onPressed: _onRequestNotificationPermission,
                      child: Text(_notificationNeedsSettings ? 'Открыть настройки' : 'Разрешить уведомления'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: layout.spaceL),
          ],
          if (showBatteryCard) ...[
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: EdgeInsets.all(layout.spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Часть телефонов замедляет работу в фоне. Исключите приложение из оптимизации батареи — так надёжнее дойдут напоминания и проверка пропуска.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                    ),
                    SizedBox(height: layout.spaceM),
                    FilledButton.tonalIcon(
                      onPressed: _batteryOptimizationIgnored == null ? null : _onRequestIgnoreBatteryOptimization,
                      icon: const Icon(Icons.battery_saver),
                      label: const Text('Исключить из оптимизации батареи'),
                    ),
                    SizedBox(height: layout.spaceS),
                    OutlinedButton.icon(
                      onPressed: _batteryOptimizationIgnored == null ? null : _onOpenBatteryOptimizationSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Настройки батареи для приложения'),
                    ),
                    if (_batteryOptimizationIgnored == null)
                      Padding(
                        padding: EdgeInsets.only(top: layout.spaceS),
                        child: Text(
                          'Проверяем статус…',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: layout.spaceL),
          ],
          if (_kUiShowBatteryOptimizationOkBanner &&
              Platform.isAndroid &&
              auth.isAuthenticated &&
              auth.role == 'patient' &&
              intake.hasMedications &&
              _batteryOptimizationIgnored == true) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
              title: Text(
                'Оптимизация батареи не ограничивает приложение',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            SizedBox(height: layout.spaceM),
          ],
          if (!intake.hasMedications) ...[
            Text('Добавьте препараты на вкладке «Таблетки» — интервал или график подтянется сюда автоматически.', style: theme.textTheme.bodyLarge),
          ] else ...[
            if (intake.hasAnySchedule) ...[
              Text(
                intake.isDue ? 'Пора принять' : 'До ближайшего приёма',
                style: theme.textTheme.titleLarge,
              ),
              SizedBox(height: layout.spaceS),
              Text(
                _format(intake.remainingUntilNext ?? Duration.zero),
                style: theme.textTheme.displayLarge,
              ),
              if (intake.isDue && intake.globalEarliestFuture != null) ...[
                SizedBox(height: layout.spaceXs),
                Text(
                  'Пока приём не подтверждён, циферблат — время до ближайшего следующего слота (в том числе другие препараты).',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: layout.spaceS),
              Text(
                (intake.isDue ? intake.dueFocusNames() : intake.namesForGlobalEarliest()).join(', '),
                style: theme.textTheme.bodyLarge,
              ),
              if (intake.isDue) ...[
                SizedBox(height: layout.spaceL),
                FilledButton(
                  onPressed: () => context.read<IntakeTimerController>().confirm(),
                  child: const Text('Подтвердить приём'),
                ),
                SizedBox(height: layout.spaceM),
                OutlinedButton(
                  onPressed: () => context.read<IntakeTimerController>().snooze(),
                  child: const Text('Отложить на +15 мин'),
                ),
              ],
            ] else ...[
              Text(
                'Укажите для препаратов интервал (минуты) или времена по графику (ЧЧ:ММ) — тогда появится обратный отсчёт.',
                style: theme.textTheme.bodyLarge,
              ),
            ],
            SizedBox(height: layout.spaceXl),
            Text('Препараты и следующий приём', style: theme.textTheme.titleLarge),
            SizedBox(height: layout.spaceM),
            ...intake.medicationsSortedByNextDue.map((m) {
              final at = intake.nextDueById[m.id];
              final modeHint = m.reminderMode == ReminderMode.scheduledSlots ? 'По графику' : 'Интервал';
              final subtitle = at == null
                  ? '$modeHint · нет ближайшего времени (проверьте настройки)'
                  : '$modeHint · следующий: ${_fmtTime(at)} · ${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')}';
              return SizedBox(
                width: double.infinity,
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    title: Text(m.name, style: theme.textTheme.titleLarge),
                    subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
      ),
    );
  }
}
