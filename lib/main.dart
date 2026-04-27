import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';

import 'app/router/app_router.dart';
import 'app/services/app_services.dart';
import 'app/services/notification_service.dart';
import 'app/services/timezone_setup.dart';
import 'app/storage/get_storage_key_value_store.dart';
import 'app/time2t3_app.dart';
import 'data/sources/remote/mock_remote_data_source.dart';
import 'features/connectivity/connectivity_notifier.dart';
import 'features/medications/medications_controller.dart';
import 'features/profile/patient_controller.dart';
import 'features/profile/ui_preferences_controller.dart';
import 'features/timer/intake_timer_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await configureLocalTimeZone();

  final store = GetStorageKeyValueStore();
  final notifications = NotificationService();
  await notifications.init();
  if (Platform.isAndroid) {
    await notifications.ensureAndroidSchedulePermissions();
  }

  final remote = MockRemoteDataSource();
  final appServices = AppServices(
    store: store,
    notifications: notifications,
    remote: remote,
  );
  await appServices.init();

  final intakeTimer = IntakeTimerController(appServices);
  notifications.onConfirmFromNotification = () {
    intakeTimer.confirm();
  };
  notifications.onSnoozeFromNotification = () {
    intakeTimer.snooze();
  };
  await intakeTimer.restore();

  final router = createAppRouter();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppServices>.value(value: appServices),
        ChangeNotifierProvider(
          create: (_) {
            final n = ConnectivityNotifier();
            n.start();
            return n;
          },
        ),
        ChangeNotifierProvider<IntakeTimerController>.value(value: intakeTimer),
        ChangeNotifierProvider(
          create: (_) {
            final c = MedicationsController(appServices, intakeTimer);
            c.load();
            return c;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final c = PatientController(appServices);
            c.load();
            return c;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final c = UiPreferencesController(appServices.store);
            unawaited(c.load());
            return c;
          },
        ),
      ],
      child: Time2T3App(router: router),
    ),
  );
}
