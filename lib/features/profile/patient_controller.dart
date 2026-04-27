import 'package:flutter/foundation.dart';

import '../../app/services/app_services.dart';
import '../../core/models/patient_profile.dart';

class PatientController extends ChangeNotifier {
  PatientController(this._services);

  final AppServices _services;
  PatientProfile? _profile;

  PatientProfile? get profile => _profile;

  Future<void> load() async {
    _profile = await _services.patient.loadLocal();
    notifyListeners();
  }

  Future<void> save(PatientProfile next) async {
    await _services.patient.upsertLocalEnqueue(next);
    try {
      await _services.syncRemoteNow();
    } catch (_) {}
    await load();
  }
}
