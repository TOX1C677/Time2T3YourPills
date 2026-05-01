import 'package:flutter/foundation.dart';

import '../../app/services/app_services.dart';
import '../../core/models/medication.dart';
import '../timer/intake_timer_controller.dart';

class MedicationsController extends ChangeNotifier {
  MedicationsController(this._services, this._intakeTimer);

  final AppServices _services;
  final IntakeTimerController _intakeTimer;
  List<Medication> _items = [];

  List<Medication> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _items = await _services.medications.loadLocal();
    notifyListeners();
    await _intakeTimer.refreshFromMedications();
  }

  /// Подтянуть с сервера при пустой outbox-очереди (см. [MedicationsRepository.pullMergePreferLocal]).
  Future<void> refreshFromServer() async {
    _items = await _services.medications.pullMergePreferLocal();
    notifyListeners();
    await _intakeTimer.refreshFromMedications();
  }

  Future<void> upsert(Medication medication) async {
    await _services.medications.upsertLocalEnqueue(medication);
    try {
      await _services.syncRemoteNow();
    } catch (_) {}
    await load();
  }

  Future<void> removeById(String id) async {
    await _services.medications.deleteLocalEnqueue(id);
    try {
      await _services.syncRemoteNow();
    } catch (_) {}
    await load();
  }
}
