import 'package:flutter/foundation.dart';

import '../auth/auth_session.dart';

/// Список привязанных пациентов и выбранный `patient_user_id` для запросов `/v1/caregiver/patients/{id}/…`.
class CaregiverScope extends ChangeNotifier {
  CaregiverScope(this._auth);

  final AuthSession _auth;

  List<CaregiverPatientOption> _patients = [];
  String? _selectedPatientUserId;

  List<CaregiverPatientOption> get patients => List.unmodifiable(_patients);

  String? get selectedPatientUserId => _selectedPatientUserId;

  void clear() {
    _patients = [];
    _selectedPatientUserId = null;
    notifyListeners();
  }

  Future<void> refreshFromApi() async {
    if (_auth.role != 'caregiver' || !_auth.isAuthenticated) {
      clear();
      return;
    }
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
    final mn = j['middle_name'] as String? ?? '';
    final composed = '$fn $mn'.trim();
    final label = composed.isNotEmpty ? composed : (dn.isNotEmpty ? dn : id);
    return CaregiverPatientOption(patientUserId: id, label: label);
  }
}
