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
    final fitRaw = (m['first_intake_time'] as String?)?.trim();
    return Medication(
      id: id,
      name: m['name'] as String? ?? '',
      dosage: m['dosage'] as String? ?? '',
      reminderMode: ReminderMode.fromStorage(modeRaw),
      intervalMinutes: (m['interval_minutes'] as num?)?.toInt(),
      slotTimes: (m['slot_times'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      firstIntakeHm: (fitRaw != null && fitRaw.isNotEmpty) ? fitRaw : null,
      updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null,
    );
  }

  static Map<String, dynamic> _medicationToUpsertBody(Medication m) {
    final f = m.firstIntakeHm;
    return {
      'name': m.name,
      'dosage': m.dosage,
      'reminder_mode': m.reminderMode.storageValue,
      'interval_minutes': m.intervalMinutes,
      'slot_times': m.slotTimes.isEmpty ? null : m.slotTimes,
      'first_intake_time': (f != null && f.isNotEmpty) ? f : null,
    };
  }

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
    if (!_auth.isAuthenticated) return null;
    if (_auth.role == 'patient') {
      final res = await _auth.dio.get<Map<String, dynamic>>('/v1/patients/me/profile');
      final m = res.data!;
      return PatientProfile(
        name: m['first_name'] as String? ?? '',
        surname: m['last_name'] as String? ?? '',
        updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null,
      );
    }
    if (_auth.role == 'caregiver') {
      final res = await _auth.dio.get<Map<String, dynamic>>('/v1/users/me');
      return _patientProfileFromUserMe(res.data!);
    }
    return null;
  }

  /// Опекун: в БД только `users.display_name` (регистрация), без строки patient_profiles.
  static PatientProfile _patientProfileFromUserMe(Map<String, dynamic> m) {
    final dn = (m['display_name'] as String? ?? '').trim();
    final email = (m['email'] as String? ?? '').trim();
    if (dn.isEmpty) {
      final short = email.contains('@') ? email.split('@').first : email;
      return PatientProfile(name: short.isNotEmpty ? short : 'Опекун', surname: '');
    }
    final parts = dn.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return PatientProfile(name: parts.first, surname: parts.sublist(1).join(' '));
    }
    return PatientProfile(name: dn, surname: '');
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

  /// Фиксация пропуска для опекунов после игнорирования двух 15-минутных напоминаний.
  Future<void> postReminderEscalation(List<Map<String, String>> items) async {
    if (!_auth.isAuthenticated || _auth.role != 'patient') return;
    await _auth.dio.post<void>(
      '/v1/patients/me/reminder-escalation',
      data: {
        'items': items
            .map((e) => {'medication_id': e['medication_id'], 'due_at': e['due_at']})
            .toList(),
      },
    );
  }

  Future<void> _patchPatientProfile(Map<String, Object?> map) async {
    await _auth.dio.patch<Map<String, dynamic>>(
      '/v1/patients/me/profile',
      data: {
        'first_name': map['name'] ?? '',
        'last_name': map['surname'] ?? '',
        'middle_name': '',
      },
    );
  }

  Future<void> _patchCaregiverDisplayName(Map<String, Object?> map) async {
    final name = (map['name'] as String? ?? '').trim();
    final surname = (map['surname'] as String? ?? '').trim();
    final parts = <String>[name, surname].where((s) => s.isNotEmpty);
    final displayName = parts.join(' ').trim();
    await _auth.dio.patch<Map<String, dynamic>>(
      '/v1/users/me',
      data: {'display_name': displayName},
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
        final map = Map<String, Object?>.from(jsonDecode(e.payloadJson) as Map);
        if (_auth.role == 'patient') {
          await _patchPatientProfile(map);
        } else if (_auth.role == 'caregiver') {
          await _patchCaregiverDisplayName(map);
        }
      } else if (e.type == 'intake_event') {
        if (_auth.role != 'patient') continue;
        final map = Map<String, dynamic>.from(jsonDecode(e.payloadJson) as Map);
        await postIntakeEvent(map);
      }
    }
  }
}
