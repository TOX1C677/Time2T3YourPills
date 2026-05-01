import '../../../core/models/medication.dart';
import '../../../core/models/outbox_entry.dart';
import '../../../core/models/patient_profile.dart';

/// Удалённая синхронизация препаратов и профиля (мок или REST).
abstract class RemoteSyncDataSource {
  Future<void> seedIfEmpty();

  Future<void> applyOutboxEntries(List<OutboxEntry> entries);

  Future<List<Medication>> fetchMedications();

  Future<PatientProfile?> fetchPatient();
}
