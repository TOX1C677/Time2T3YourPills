import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../app/services/app_services.dart';
import '../../app/storage/storage_keys.dart';
import '../../core/models/medication.dart';
import '../../core/models/reminder_mode.dart';
import '../../core/services/intake_schedule.dart';
import 'intake_reminder_escalation.dart';
import 'intake_timer_state.dart';

/// Таймер по всем препаратам: на экране — до ближайшего приёма; у каждого свой nextDue; уведомление по ближайшему событию.
class IntakeTimerController extends ChangeNotifier {
  IntakeTimerController(this._services);

  final AppServices _services;
  Timer? _ticker;
  int _caregiverEscalationClock = 0;

  List<Medication> _medications = [];
  Map<String, DateTime> _nextDue = {};
  DateTime? _lastScheduledAt;
  List<String> _lastScheduledMedIds = [];

  List<Medication> get medications => List.unmodifiable(_medications);

  /// Препараты с валидным nextDue — от ближайшего приёма к более позднему.
  List<Medication> get medicationsSortedByNextDue {
    final list = List<Medication>.from(_medications);
    list.sort((a, b) {
      final at = _nextDue[a.id];
      final bt = _nextDue[b.id];
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    });
    return list;
  }

  Map<String, DateTime> get nextDueById => Map.unmodifiable(_nextDue);

  DateTime? get globalEarliest {
    if (_nextDue.isEmpty) return null;
    return _nextDue.values.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Ближайший приём строго в будущем (игнорируя просроченные до подтверждения / +15 мин).
  /// Нужен, чтобы при «висящем» приёме одного препарата продолжать отсчёт до слотов других.
  DateTime? get globalEarliestFuture => _earliestStrictlyFuture(DateTime.now());

  DateTime? _earliestStrictlyFuture(DateTime now) {
    DateTime? best;
    for (final t in _nextDue.values) {
      if (!t.isAfter(now)) continue;
      if (best == null || t.isBefore(best)) best = t;
    }
    return best;
  }

  /// Есть препараты в списке (включая «по графику») — экран таймера не в режиме онбординга.
  bool get hasMedications => _medications.isNotEmpty;

  /// Есть хотя бы один рассчитанный следующий приём — показываем обратный отсчёт и уведомления.
  bool get hasAnySchedule => _nextDue.isNotEmpty;

  bool get isDue {
    final e = globalEarliest;
    return e != null && !e.isAfter(DateTime.now());
  }

  Duration? get remainingUntilNext {
    final now = DateTime.now();
    final e = globalEarliest;
    if (e == null) return null;
    if (!e.isAfter(now)) {
      // Есть просрочка: большой таймер показывает время до ближайшего будущего слота (другие препараты),
      // пока текущий(е) просроченный(е) ждут «Принял» / +15 мин — их _nextDue не сдвигаем.
      final future = _earliestStrictlyFuture(now);
      if (future != null) {
        final diff = future.difference(now);
        return diff.isNegative ? Duration.zero : diff;
      }
      return Duration.zero;
    }
    final diff = e.difference(now);
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  List<String> namesForGlobalEarliest() {
    final t = globalEarliest;
    if (t == null) return const [];
    final ids = _idsAtInstant(t);
    return _medications.where((m) => ids.contains(m.id)).map((m) => m.name).where((n) => n.isNotEmpty).toList();
  }

  List<String> dueFocusNames() {
    final t = _focusOverdueInstant();
    if (t == null) return const [];
    final ids = _idsAtInstant(t);
    return _medications.where((m) => ids.contains(m.id)).map((m) => m.name).toList();
  }

  DateTime? _focusOverdueInstant() {
    final now = DateTime.now();
    final overdue = _nextDue.entries.where((e) => !e.value.isAfter(now)).toList();
    if (overdue.isEmpty) return null;
    return overdue.map((e) => e.value).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  List<String> _idsAtInstant(DateTime t) {
    return _nextDue.entries
        .where((e) => IntakeSchedule.sameInstant(e.value, t))
        .map((e) => e.key)
        .toList();
  }

  Medication? _medById(String id) {
    for (final m in _medications) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> restore() async {
    await refreshFromMedications();
  }

  Future<void> refreshFromMedications() async {
    _medications = await _services.medications.loadLocal();
    final stored = IntakeTimerState.tryParse(await _services.store.read(StorageKeys.intakeTimerStateJson));
    _nextDue = Map<String, DateTime>.from(stored?.nextDueById ?? {});
    _lastScheduledAt = stored?.lastScheduledAt;
    _lastScheduledMedIds = List<String>.from(stored?.lastScheduledMedIds ?? const []);

    final now = DateTime.now();
    if (_lastScheduledAt != null && !_lastScheduledAt!.isAfter(now)) {
      final age = now.difference(_lastScheduledAt!);
      if (age > const Duration(hours: 12)) {
        _lastScheduledMedIds = [];
        _lastScheduledAt = null;
      }
    }

    for (final m in _medications) {
      if (!IntakeSchedule.medicationHasActiveReminder(m)) {
        _nextDue.remove(m.id);
        continue;
      }
      if (!_nextDue.containsKey(m.id)) {
        final initial = IntakeSchedule.initialNextDueForMedication(m, now);
        if (initial != null) _nextDue[m.id] = initial;
      }
    }
    _nextDue.removeWhere((id, _) => !_medications.any((med) => med.id == id));

    _lastScheduledMedIds.removeWhere((id) => !_medications.any((med) => med.id == id));
    if (_nextDue.isEmpty) {
      _lastScheduledMedIds = [];
      _lastScheduledAt = null;
    }

    await _persistAndReschedule();
    _startTicker();
    notifyListeners();
  }

  Future<void> confirm() async {
    final ids = _targetMedIds();
    if (ids.isEmpty) {
      await refreshFromMedications();
      return;
    }
    final now = DateTime.now();
    for (final id in ids) {
      final m = _medById(id);
      if (m == null) continue;
      final due = _nextDue[id];
      if (due != null) {
        await _services.recordIntakeConfirmed(
          medicationId: id,
          scheduledAt: due,
          medicationName: m.name,
          dosage: m.dosage,
        );
      }
      if (m.reminderMode == ReminderMode.fixedInterval && m.intervalMinutes != null && m.intervalMinutes! > 0) {
        _nextDue[id] = now.add(Duration(minutes: m.intervalMinutes!));
      } else {
        final next = IntakeSchedule.nextSlotAfter(now, m.slotTimes);
        if (next != null) {
          _nextDue[id] = next;
        } else {
          _nextDue.remove(id);
        }
      }
    }
    _lastScheduledMedIds = [];
    _lastScheduledAt = null;
    await _persistAndReschedule();
    notifyListeners();
  }

  Future<void> snooze() async {
    final ids = _targetMedIds();
    if (ids.isEmpty) return;
    final now = DateTime.now();
    for (final id in ids) {
      _nextDue[id] = now.add(const Duration(minutes: 15));
    }
    _lastScheduledMedIds = [];
    _lastScheduledAt = null;
    await _persistAndReschedule();
    notifyListeners();
  }

  List<String> _targetMedIds() {
    if (_lastScheduledMedIds.isNotEmpty) return List<String>.from(_lastScheduledMedIds);
    final t = _focusOverdueInstant();
    if (t == null) return const [];
    return _idsAtInstant(t);
  }

  bool _isEscalationStillPending(IntakeReminderEscalation esc) {
    final t = _focusOverdueInstant();
    if (t == null) return false;
    if (!IntakeSchedule.sameInstant(t, esc.overdueInstant, toleranceMs: 120000)) return false;
    final atDue = _idsAtInstant(t).toSet();
    for (final id in esc.medicationIds) {
      if (!atDue.contains(id)) return false;
    }
    return true;
  }

  Future<void> _maybeFireCaregiverEscalation() async {
    _caregiverEscalationClock++;
    if (_caregiverEscalationClock % 5 != 0) return;

    final raw = await _services.store.read(StorageKeys.intakeReminderEscalationJson);
    final esc = IntakeReminderEscalation.tryParse(raw);
    if (esc == null || esc.caregiverApiSent) return;
    if (DateTime.now().isBefore(esc.caregiverNotifyAt)) return;
    if (!_isEscalationStillPending(esc)) {
      await _services.store.remove(StorageKeys.intakeReminderEscalationJson);
      return;
    }
    final items = <Map<String, String>>[];
    for (final id in esc.medicationIds) {
      final due = esc.dueAtIsoUtcByMedId[id];
      if (due != null) {
        items.add({'medication_id': id, 'due_at': due});
      }
    }
    if (items.isEmpty) return;
    try {
      await _services.notifyReminderEscalationToCaregivers(items);
      await _services.store.write(
        StorageKeys.intakeReminderEscalationJson,
        esc.copyWith(sent: true).toJsonString(),
      );
    } catch (_) {}
  }

  Future<void> _persistAndReschedule() async {
    final state = IntakeTimerState(
      nextDueById: _nextDue,
      lastScheduledAt: _lastScheduledAt,
      lastScheduledMedIds: _lastScheduledMedIds,
    );
    await _services.store.write(StorageKeys.intakeTimerStateJson, state.toJsonString());

    await _services.notifications.cancelTimerEnd();
    if (_nextDue.isEmpty) {
      await _services.store.remove(StorageKeys.intakeReminderEscalationJson);
      return;
    }

    final now = DateTime.now();
    final futureEarliest = _earliestStrictlyFuture(now);
    final hasOverdue = _nextDue.entries.any((e) => !e.value.isAfter(now));

    late final DateTime scheduleAt;
    late final List<String> ids;

    if (futureEarliest != null && !hasOverdue) {
      scheduleAt = futureEarliest;
      ids = _idsAtInstant(futureEarliest);
    } else if (futureEarliest != null && hasOverdue) {
      final nag = now.add(const Duration(seconds: 3));
      if (!futureEarliest.isAfter(nag)) {
        scheduleAt = futureEarliest;
        ids = _idsAtInstant(futureEarliest);
      } else {
        scheduleAt = nag;
        final overT = _focusOverdueInstant();
        if (overT == null) {
          await _services.store.remove(StorageKeys.intakeReminderEscalationJson);
          return;
        }
        ids = _idsAtInstant(overT);
      }
    } else if (hasOverdue) {
      final overT = _focusOverdueInstant();
      if (overT == null) {
        await _services.store.remove(StorageKeys.intakeReminderEscalationJson);
        return;
      }
      scheduleAt = now.add(const Duration(seconds: 3));
      ids = _idsAtInstant(overT);
    } else {
      await _services.store.remove(StorageKeys.intakeReminderEscalationJson);
      return;
    }

    if (ids.isEmpty) {
      await _services.store.remove(StorageKeys.intakeReminderEscalationJson);
      return;
    }

    // AlarmManager на части устройств не принимает время «прямо сейчас» — сдвигаем на пару секунд вперёд.
    var when = scheduleAt;
    if (!when.isAfter(now.add(const Duration(seconds: 2)))) {
      when = now.add(const Duration(seconds: 3));
    }

    final names = _medications.where((m) => ids.contains(m.id)).map((m) => m.name).where((n) => n.isNotEmpty).toList();
    final title = names.isEmpty ? 'Лекарство' : (names.length == 1 ? names.first : names.join(', '));

    _lastScheduledAt = when;
    _lastScheduledMedIds = ids;

    await _services.store.write(
      StorageKeys.intakeTimerStateJson,
      IntakeTimerState(
        nextDueById: _nextDue,
        lastScheduledAt: _lastScheduledAt,
        lastScheduledMedIds: _lastScheduledMedIds,
      ).toJsonString(),
    );

    await _services.notifications.scheduleTimerEnd(
      whenLocal: when,
      medicationName: title,
    );

    final overdueInstantForEscalation = hasOverdue ? _focusOverdueInstant()! : scheduleAt;
    final dueMap = <String, String>{};
    for (final id in ids) {
      final d = _nextDue[id];
      if (d != null) {
        dueMap[id] = d.toUtc().toIso8601String();
      }
    }
    final esc = IntakeReminderEscalation(
      anchorLocal: when,
      overdueInstant: overdueInstantForEscalation,
      medicationIds: List<String>.from(ids),
      dueAtIsoUtcByMedId: dueMap,
    );
    await _services.store.write(StorageKeys.intakeReminderEscalationJson, esc.toJsonString());
    await _services.notifications.scheduleReminderEscalations(
      anchorLocal: when,
      medicationName: title,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
      unawaited(_maybeFireCaregiverEscalation());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
