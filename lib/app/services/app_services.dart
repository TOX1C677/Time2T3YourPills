import 'dart:convert';

import '../../data/repositories/medications_repository.dart';
import '../../data/repositories/outbox_repository.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/sources/remote/api_remote_data_source.dart';
import '../../data/sources/remote/remote_sync_data_source.dart';
import '../storage/key_value_store.dart';
import '../storage/storage_keys.dart';
import 'notification_service.dart';

/// Composition root: удалённый слой (`RemoteSyncDataSource`), KV, уведомления, репозитории. Поднимается в `main.dart`.
class AppServices {
  AppServices({
    required this.store,
    required this.notifications,
    required this.remote,
    bool Function()? canApplyOutbox,
    required String Function() outboxStorageKey,
    required String Function() medicationsStorageKey,
    required String Function() patientStorageKey,
  }) : _canApplyOutbox = canApplyOutbox ?? (() => true) {
    outbox = OutboxRepository(store, storageKey: outboxStorageKey);
    medications = MedicationsRepository(
      store,
      remote,
      outbox,
      storageKey: medicationsStorageKey,
    );
    patient = PatientRepository(
      store,
      remote,
      outbox,
      storageKey: patientStorageKey,
    );
  }

  final KeyValueStore store;
  final NotificationService notifications;
  final RemoteSyncDataSource remote;
  final bool Function() _canApplyOutbox;

  late final OutboxRepository outbox;
  late final MedicationsRepository medications;
  late final PatientRepository patient;

  /// Вызывается после [syncRemoteNow] записал препараты на диск — подтянуть [MedicationsController] и [IntakeTimerController].
  void Function()? onMedicationsPersistedFromSync;

  Future<void> init() async {
    await remote.seedIfEmpty();
  }

  /// Полный сброс локальных снимков и outbox (смена аккаунта / выход).
  Future<void> clearUserBoundLocalCache() async {
    await store.removeKeysWithPrefix('cache.medications.v3.');
    await store.removeKeysWithPrefix('cache.patient.v3.');
    await store.removeKeysWithPrefix('sync.outbox.v3.');
    await store.remove(StorageKeys.medicationsJson);
    await store.remove(StorageKeys.patientProfileJson);
    await store.remove(StorageKeys.outboxJson);
    await store.remove(StorageKeys.intakeTimerStateJson);
    await store.remove(StorageKeys.intakeReminderEscalationJson);
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
    onMedicationsPersistedFromSync?.call();
    final p = await remote.fetchPatient();
    if (p != null) {
      await patient.persistLocal(p);
    }
  }

  /// Запись подтверждённого приёма на сервер; при ошибке сети — в outbox (`intake_event`).
  Future<void> recordIntakeConfirmed({
    required String medicationId,
    required DateTime scheduledAt,
    required String medicationName,
    required String dosage,
  }) async {
    final body = <String, dynamic>{
      'medication_id': medicationId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'confirmed',
      'medication_name_snapshot': medicationName,
      'dosage_snapshot': dosage,
      'source': 'patient_app',
    };
    final remote = this.remote;
    if (remote is ApiRemoteDataSource) {
      try {
        await remote.postIntakeEvent(body);
        return;
      } catch (_) {
        await outbox.enqueue(type: 'intake_event', payloadJson: jsonEncode(body));
        return;
      }
    }
  }

  /// Алерты опекунам после 30 мин без реакции на напоминания (только пациент, только REST).
  Future<void> notifyReminderEscalationToCaregivers(List<Map<String, String>> items) async {
    final remote = this.remote;
    if (remote is! ApiRemoteDataSource || items.isEmpty) return;
    try {
      await remote.postReminderEscalation(items);
    } catch (_) {}
  }
}
