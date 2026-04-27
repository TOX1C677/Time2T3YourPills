import 'package:flutter_test/flutter_test.dart';
import 'package:time2t3_your_pills/core/models/medication.dart';
import 'package:time2t3_your_pills/core/models/reminder_mode.dart';
import 'package:time2t3_your_pills/core/services/intake_schedule.dart';

void main() {
  test('nextSlotAfter picks same-day later slot', () {
    final from = DateTime(2026, 4, 24, 10, 30);
    final next = IntakeSchedule.nextSlotAfter(from, const ['08:00', '20:00']);
    expect(next, DateTime(2026, 4, 24, 20, 0));
  });

  test('interval vs schedule: earliest of two future instants', () {
    final t0 = DateTime(2026, 4, 24, 0, 0);
    final a = t0.add(const Duration(hours: 3));
    final b = t0.add(const Duration(hours: 4));
    final earliest = IntakeSchedule.earliestOf([a, b])!;
    expect(earliest, a);
  });

  test('initialNextDueForMedication interval', () {
    final now = DateTime(2026, 4, 24, 12, 0);
    final m = Medication(
      id: '1',
      name: 'A',
      dosage: '1',
      reminderMode: ReminderMode.fixedInterval,
      intervalMinutes: 180,
    );
    final next = IntakeSchedule.initialNextDueForMedication(m, now);
    expect(next, now.add(const Duration(hours: 3)));
  });
}
