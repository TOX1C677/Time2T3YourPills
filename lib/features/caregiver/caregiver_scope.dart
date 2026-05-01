import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_session.dart';

/// Список привязанных пациентов и выбранный `patient_user_id` для запросов `/v1/caregiver/patients/{id}/…`.
class CaregiverScope extends ChangeNotifier {
  CaregiverScope(this._auth);

  final AuthSession _auth;

  List<CaregiverPatientOption> _patients = [];
  String? _selectedPatientUserId;
  int _missedAlertsCount = 0;

  List<CaregiverPatientOption> get patients => List.unmodifiable(_patients);

  String? get selectedPatientUserId => _selectedPatientUserId;

  /// Число записей `GET /v1/caregiver/alerts` (для бейджа в shell).
  int get missedAlertsCount => _missedAlertsCount;

  void clear() {
    _patients = [];
    _selectedPatientUserId = null;
    _missedAlertsCount = 0;
    notifyListeners();
  }

  Future<void> refreshMissedAlertsCount() async {
    if (_auth.role != 'caregiver' || !_auth.isAuthenticated) {
      _missedAlertsCount = 0;
      notifyListeners();
      return;
    }
    try {
      final res = await _auth.dio.get<List<dynamic>>('/v1/caregiver/alerts');
      _missedAlertsCount = (res.data ?? []).length;
    } catch (_) {
      // оставляем предыдущее значение
    }
    notifyListeners();
  }

  /// [revokeSessionOnUnauthorized]: при 401 вызвать [AuthSession.logout] (инвалидация refresh на сервере).
  /// После свежего `login`/`register` передавайте `false`: иначе любой ложный/граничный 401 на
  /// `GET /v1/caregiver/patients` сотрёт только что выданные токены и «вход» не удастся.
  Future<void> refreshFromApi({bool revokeSessionOnUnauthorized = false}) async {
    if (_auth.role != 'caregiver' || !_auth.isAuthenticated) {
      clear();
      return;
    }
    try {
      final res = await _auth.dio.get<List<dynamic>>('/v1/caregiver/patients');
      final list = (res.data ?? [])
          .map((e) => CaregiverPatientOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _patients = list;
      if (_selectedPatientUserId == null && list.isNotEmpty) {
        _selectedPatientUserId = list.first.patientUserId;
      } else if (_selectedPatientUserId != null &&
          !list.any((p) => p.patientUserId == _selectedPatientUserId)) {
        _selectedPatientUserId = list.isNotEmpty ? list.first.patientUserId : null;
      }
    } catch (e) {
      final code = e is DioException ? e.response?.statusCode : null;
      if (code == 401) {
        clear();
        if (revokeSessionOnUnauthorized) {
          await _auth.logout();
        }
      }
      // остальное (сеть) — оставляем предыдущий список
    }
    notifyListeners();
  }

  void selectPatient(String? patientUserId) {
    _selectedPatientUserId = patientUserId;
    notifyListeners();
  }
}

class CaregiverPatientOption {
  CaregiverPatientOption({required this.patientUserId, required this.label});

  final String patientUserId;
  final String label;

  static CaregiverPatientOption fromJson(Map<String, dynamic> j) {
    final id = j['patient_user_id']?.toString() ?? '';
    final dn = j['display_name'] as String? ?? '';
    final fn = j['first_name'] as String? ?? '';
    final ln = j['last_name'] as String? ?? '';
    final mn = j['middle_name'] as String? ?? '';
    final composed = [fn, ln, mn].where((s) => s.trim().isNotEmpty).join(' ');
    final label = composed.isNotEmpty ? composed : (dn.isNotEmpty ? dn : id);
    return CaregiverPatientOption(patientUserId: id, label: label);
  }
}
