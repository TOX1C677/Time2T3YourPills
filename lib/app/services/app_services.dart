import '../../data/repositories/medications_repository.dart';
import '../../data/repositories/outbox_repository.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/sources/remote/remote_sync_data_source.dart';
import '../storage/key_value_store.dart';
import 'notification_service.dart';

/// Composition root: удалённый слой (`RemoteSyncDataSource`), KV, уведомления, репозитории. Поднимается в `main.dart`.
class AppServices {
  AppServices({
    required this.store,
    required this.notifications,
    required this.remote,
    bool Function()? canApplyOutbox,
  }) : _canApplyOutbox = canApplyOutbox ?? (() => true) {
    outbox = OutboxRepository(store);
    medications = MedicationsRepository(store, remote, outbox);
    patient = PatientRepository(store, remote, outbox);
  }

  final KeyValueStore store;
  final NotificationService notifications;
  final RemoteSyncDataSource remote;
  final bool Function() _canApplyOutbox;

  late final OutboxRepository outbox;
  late final MedicationsRepository medications;
  late final PatientRepository patient;

  Future<void> init() async {
    await remote.seedIfEmpty();
  }

  /// Отправить outbox на API (если есть и разрешён вход), затем подтянуть препараты и профиль с сервера.
  Future<void> syncRemoteNow() async {
    final pending = await outbox.readAll();
    if (pending.isNotEmpty) {
      if (!_canApplyOutbox()) {
        return;
      }
      await remote.applyOutboxEntries(pending);
      await outbox.clear();
    }
    if (!_canApplyOutbox()) {
      return;
    }
    final meds = await remote.fetchMedications();
    await medications.persistLocal(meds);
    final p = await remote.fetchPatient();
    if (p != null) {
      await patient.persistLocal(p);
    }
  }
}
