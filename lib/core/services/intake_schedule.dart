import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../models/reminder_mode.dart';

/// Чистая логика: следующий слот по графику и сравнение моментов приёма.
abstract final class IntakeSchedule {
  static TimeOfDay? parseSlotHm(String raw) {
    final parts = raw.trim().split(RegExp(r'[:.]'));
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Ближайший момент слота строго после [from] (до 14 суток вперёд).
  static DateTime? nextSlotAfter(DateTime from, List<String> slotTimes) {
    if (slotTimes.isEmpty) return null;
    final fromDay = DateTime(from.year, from.month, from.day);
    DateTime? best;
    for (var d = 0; d < 14; d++) {
      final day = fromDay.add(Duration(days: d));
      for (final s in slotTimes) {
        final tod = parseSlotHm(s);
        if (tod == null) continue;
        final cand = DateTime(day.year, day.month, day.day, tod.hour, tod.minute);
        if (!cand.isAfter(from)) continue;
        if (best == null || cand.isBefore(best)) best = cand;
      }
    }
    return best;
  }

  /// Есть ли у препарата настройки, по которым таймер может считать следующий приём.
  static bool medicationHasActiveReminder(Medication m) {
    switch (m.reminderMode) {
      case ReminderMode.fixedInterval:
        final min = m.intervalMinutes;
        return min != null && min > 0;
      case ReminderMode.scheduledSlots:
        if (m.slotTimes.isEmpty) return false;
        return m.slotTimes.any((s) => parseSlotHm(s) != null);
    }
  }

  static DateTime? initialNextDueForMedication(Medication m, DateTime now) {
    switch (m.reminderMode) {
      case ReminderMode.fixedInterval:
        final min = m.intervalMinutes;
        if (min == null || min <= 0) return null;
        return now.add(Duration(minutes: min));
      case ReminderMode.scheduledSlots:
        if (m.slotTimes.isEmpty) return null;
        return nextSlotAfter(now, m.slotTimes);
    }
  }

  static bool sameInstant(DateTime a, DateTime b, {int toleranceMs = 1500}) {
    return (a.millisecondsSinceEpoch - b.millisecondsSinceEpoch).abs() <= toleranceMs;
  }

  /// Минимальный среди переданных моментов (игнорируя null).
  static DateTime? earliestOf(Iterable<DateTime> times) {
    DateTime? best;
    for (final t in times) {
      if (best == null || t.isBefore(best)) best = t;
    }
    return best;
  }
}
