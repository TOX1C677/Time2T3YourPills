import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';

import 'app/router/app_router.dart';
import 'app/services/app_services.dart';
import 'features/auth/auth_session.dart';
import 'app/services/notification_service.dart';
import 'app/services/timezone_setup.dart';
import 'app/storage/get_storage_key_value_store.dart';
import 'app/storage/storage_keys.dart';
import 'app/time2t3_app.dart';
import 'app/widgets/patient_foreground_binding.dart';
import 'data/sources/remote/api_remote_data_source.dart';
import 'features/caregiver/caregiver_scope.dart';
import 'features/connectivity/connectivity_notifier.dart';
import 'features/medications/medications_controller.dart';
import 'features/profile/patient_controller.dart';
import 'features/profile/ui_preferences_controller.dart';
import 'features/timer/intake_timer_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await GetStorage.init();
  await configureLocalTimeZone();

  final store = GetStorageKeyValueStore();
  final notifications = NotificationService();
  await notifications.init();
  if (Platform.isAndroid) {
    await notifications.ensureAndroidSchedulePermissions();
  }

  final auth = AuthSession();
  await auth.restore();

  final caregiverScope = CaregiverScope(auth);
  // Единственный удалённый слой к прод-API (`AppEnv` + `AuthSession.dio`); не Web, только Android.
  final remote = ApiRemoteDataSource(
    auth,
    activeCaregiverPatientId: () => caregiverScope.selectedPatientUserId,
  );
  final appServices = AppServices(
    store: store,
    notifications: notifications,
    remote: remote,
    canApplyOutbox: () => auth.isAuthenticated,
    outboxStorageKey: () => StorageKeys.outboxCacheKey(email: auth.email, role: auth.role),
    medicationsStorageKey: () => StorageKeys.medicationsCacheKey(
      email: auth.email,
      role: auth.role,
      caregiverPatientId: auth.role == 'caregiver' ? caregiverScope.selectedPatientUserId : null,
    ),
    patientStorageKey: () => StorageKeys.patientProfileCacheKey(email: auth.email, role: auth.role),
  );
  await appServices.init();

  if (auth.isAuthenticated) {
    try {
      await caregiverScope.refreshFromApi(revokeSessionOnUnauthorized: true);
      if (auth.role == 'caregiver') {
        await caregiverScope.refreshMissedAlertsCount();
      }
      await appServices.syncRemoteNow();
    } catch (_) {
      // Сеть или 401 до очистки сессии — не роняем `main`, роутер покажет вход при необходимости.
    }
  }

  final intakeTimer = IntakeTimerController(appServices);
  final medicationsController = MedicationsController(appServices, intakeTimer);
  appServices.onMedicationsPersistedFromSync = () {
    unawaited(medicationsController.load());
    unawaited(intakeTimer.refreshFromMedications());
  };
  notifications.onConfirmFromNotification = () {
    intakeTimer.confirm();
  };
  notifications.onSnoozeFromNotification = () {
    intakeTimer.snooze();
  };
  await medicationsController.load();
  await intakeTimer.restore();

  final router = createAppRouter(auth);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: caregiverScope),
        Provider<AppServices>.value(value: appServices),
        ChangeNotifierProvider(
          create: (_) {
            final n = ConnectivityNotifier();
            n.start();
            return n;
          },
        ),
        ChangeNotifierProvider<IntakeTimerController>.value(value: intakeTimer),
        ChangeNotifierProvider<MedicationsController>.value(value: medicationsController),
        ChangeNotifierProvider(
          create: (_) {
            final c = PatientController(appServices);
            c.load();
            return c;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final c = UiPreferencesController(appServices.store, auth);
            unawaited(c.load());
            return c;
          },
        ),
      ],
      child: PatientForegroundBinding(
        child: Time2T3App(router: router),
      ),
    ),
  );
}
