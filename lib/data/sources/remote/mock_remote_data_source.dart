import 'dart:convert';

import '../../../core/models/medication.dart';
import '../../../core/models/outbox_entry.dart';
import '../../../core/models/patient_profile.dart';

import 'remote_sync_data_source.dart';

/// Заглушка «сервера» до появления реального API. Очередь outbox применяется с приоритетом клиента.
class MockRemoteDataSource implements RemoteSyncDataSource {
  final List<Medication> _medications = [];
  PatientProfile? _patient;

  List<Medication> get medicationsSnapshot => List.unmodifiable(_medications);
  PatientProfile? get patientSnapshot => _patient;

  /// Имитация первичной выгрузки (пустой сервер).
  @override
  Future<void> seedIfEmpty() async {
    // оставляем пустым - данные появятся после flush outbox или локального ввода
  }

  @override
  Future<void> applyOutboxEntries(List<OutboxEntry> entries) async {
    for (final e in entries) {
      if (e.type == 'medication_upsert') {
        final map = Map<String, Object?>.from(jsonDecode(e.payloadJson) as Map);
        final m = Medication.fromJson(map);
        final idx = _medications.indexWhere((x) => x.id == m.id);
        if (idx >= 0) {
          _medications[idx] = m;
        } else {
          _medications.add(m);
        }
      } else if (e.type == 'medication_delete') {
        final map = Map<String, Object?>.from(jsonDecode(e.payloadJson) as Map);
        final id = map['id'] as String? ?? '';
        if (id.isNotEmpty) {
          _medications.removeWhere((x) => x.id == id);
        }
      } else if (e.type == 'patient_upsert') {
        final map = Map<String, Object?>.from(jsonDecode(e.payloadJson) as Map);
        _patient = PatientProfile.fromJson(map);
      }
    }
  }

  /// «Серверные» данные после применения outbox (для отладки / будущего pull).
  @override
  Future<List<Medication>> fetchMedications() async {
    return List.from(_medications);
  }

  @override
  Future<PatientProfile?> fetchPatient() async => _patient;
}
