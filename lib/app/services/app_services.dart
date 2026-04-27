import '../../data/repositories/medications_repository.dart';
import '../../data/repositories/outbox_repository.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/sources/remote/mock_remote_data_source.dart';
import '../storage/key_value_store.dart';
import 'notification_service.dart';

/// Composition root: сеть (мок), KV, уведомления, репозитории. Поднимается в `main.dart`.
class AppServices {
  AppServices({
    required this.store,
    required this.notifications,
    required this.remote,
  }) {
    outbox = OutboxRepository(store);
    medications = MedicationsRepository(store, remote, outbox);
    patient = PatientRepository(store, remote, outbox);
  }

  final KeyValueStore store;
  final NotificationService notifications;
  final MockRemoteDataSource remote;

  late final OutboxRepository outbox;
  late final MedicationsRepository medications;
  late final PatientRepository patient;

  Future<void> init() async {
    await remote.seedIfEmpty();
  }

  /// Одна точка сброса очереди на мок-сервер (и препараты, и профиль).
  Future<void> syncFlushMock() async {
    final pending = await outbox.readAll();
    if (pending.isEmpty) return;
    await remote.applyOutboxEntries(pending);
    await outbox.clear();
    final meds = await remote.fetchMedications();
    await medications.persistLocal(meds);
    final p = await remote.fetchPatient();
    if (p != null) {
      await patient.persistLocal(p);
    }
  }
}
