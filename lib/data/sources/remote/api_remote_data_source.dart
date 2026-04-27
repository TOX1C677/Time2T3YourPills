import 'dart:convert';

import '../../../core/models/medication.dart';
import '../../../core/models/outbox_entry.dart';
import '../../../core/models/patient_profile.dart';
import '../../../core/models/reminder_mode.dart';
import '../../../features/auth/auth_session.dart';
import 'remote_sync_data_source.dart';

/// REST-синхронизация с бэкендом `/v1` (см. Swagger). Опекун использует выбранного пациента из [activeCaregiverPatientId].
class ApiRemoteDataSource implements RemoteSyncDataSource {
  ApiRemoteDataSource(this._auth, {required String? Function() activeCaregiverPatientId})
      : _activeCaregiverPatientId = activeCaregiverPatientId;

  final AuthSession _auth;
  final String? Function() _activeCaregiverPatientId;

  @override
  Future<void> seedIfEmpty() async {}

  static Medication _medicationFromApiMap(Map<String, dynamic> m) {
    final id = m['id']?.toString() ?? '';
    final modeRaw = m['reminder_mode'] as String? ?? 'interval';
    return Medication(
      id: id,
      name: m['name'] as String? ?? '',
      dosage: m['dosage'] as String? ?? '',
      reminderMode: ReminderMode.fromStorage(modeRaw),
      intervalMinutes: (m['interval_minutes'] as num?)?.toInt(),
      slotTimes: (m['slot_times'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null,
    );
  }

  static Map<String, dynamic> _medicationToUpsertBody(Medication m) => {
        'name': m.name,
        'dosage': m.dosage,
        'reminder_mode': m.reminderMode.storageValue,
        'interval_minutes': m.intervalMinutes,
        'slot_times': m.slotTimes.isEmpty ? null : m.slotTimes,
      };

  @override
  Future<List<Medication>> fetchMedications() async {
    if (!_auth.isAuthenticated) return [];
    final role = _auth.role;
    if (role == 'patient') {
      final res = await _auth.dio.get<List<dynamic>>('/v1/patients/me/medications');
      final list = res.data ?? [];
      return list.map((e) => _medicationFromApiMap(Map<String, dynamic>.from(e as Map))).toList();
    }
    if (role == 'caregiver') {
      final pid = _activeCaregiverPatientId();
      if (pid == null || pid.isEmpty) return [];
      final res = await _auth.dio.get<List<dynamic>>('/v1/caregiver/patients/$pid/medications');
      final list = res.data ?? [];
      return list.map((e) => _medicationFromApiMap(Map<String, dynamic>.from(e as Map))).toList();
    }
    return [];
  }

  @override
  Future<PatientProfile?> fetchPatient() async {
    if (!_auth.isAuthenticated || _auth.role != 'patient') return null;
    final res = await _auth.dio.get<Map<String, dynamic>>('/v1/patients/me/profile');
    final m = res.data!;
    return PatientProfile(
      name: m['first_name'] as String? ?? '',
      middleName: m['middle_name'] as String? ?? '',
      updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null,
    );
  }

  Future<void> _putMedication(Medication m) async {
    final body = _medicationToUpsertBody(m);
    if (_auth.role == 'patient') {
      await _auth.dio.put<Map<String, dynamic>>('/v1/patients/me/medications/${m.id}', data: body);
      return;
    }
    if (_auth.role == 'caregiver') {
      final pid = _activeCaregiverPatientId();
      if (pid == null || pid.isEmpty) {
        throw StateError('Не выбран пациент для синхронизации таблеток');
      }
      await _auth.dio.put<Map<String, dynamic>>(
        '/v1/caregiver/patients/$pid/medications/${m.id}',
        data: body,
      );
    }
  }

  Future<void> _deleteMedication(String id) async {
    if (_auth.role == 'patient') {
      await _auth.dio.delete<void>('/v1/patients/me/medications/$id');
      return;
    }
    if (_auth.role == 'caregiver') {
      final pid = _activeCaregiverPatientId();
      if (pid == null || pid.isEmpty) {
        throw StateError('Не выбран пациент для синхронизации таблеток');
      }
      await _auth.dio.delete<void>('/v1/caregiver/patients/$pid/medications/$id');
    }
  }

  /// Запись подтверждённого приёма (только пациент).
  Future<void> postIntakeEvent(Map<String, dynamic> body) async {
    if (_auth.role != 'patient') return;
    await _auth.dio.post<Map<String, dynamic>>('/v1/patients/me/intake-events', data: body);
  }

  Future<void> _patchPatientProfile(Map<String, Object?> map) async {
    await _auth.dio.patch<Map<String, dynamic>>(
      '/v1/patients/me/profile',
      data: {
        'first_name': map['name'] ?? '',
        'middle_name': map['middleName'] ?? '',
      },
    );
  }

  @override
  Future<void> applyOutboxEntries(List<OutboxEntry> entries) async {
    if (!_auth.isAuthenticated) return;
    for (final e in entries) {
      if (e.type == 'medication_upsert') {
        final map = Map<String, Object?>.from(jsonDecode(e.payloadJson) as Map);
        final m = Medication.fromJson(map);
        await _putMedication(m);
      } else if (e.type == 'medication_delete') {
        final map = Map<String, Object?>.from(jsonDecode(e.payloadJson) as Map);
        final id = map['id'] as String? ?? '';
        if (id.isNotEmpty) {
          await _deleteMedication(id);
        }
      } else if (e.type == 'patient_upsert') {
        if (_auth.role != 'patient') continue;
        final map = Map<String, Object?>.from(jsonDecode(e.payloadJson) as Map);
        await _patchPatientProfile(map);
      } else if (e.type == 'intake_event') {
        if (_auth.role != 'patient') continue;
        final map = Map<String, dynamic>.from(jsonDecode(e.payloadJson) as Map);
        await postIntakeEvent(map);
      }
    }
  }
}
