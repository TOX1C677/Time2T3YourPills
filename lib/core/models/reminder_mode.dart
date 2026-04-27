/// Способ напоминания: равномерный интервал или фиксированные слоты времени.
enum ReminderMode {
  fixedInterval('interval'),
  scheduledSlots('schedule');

  const ReminderMode(this.storageValue);
  final String storageValue;

  static ReminderMode fromStorage(String? v) {
    for (final m in ReminderMode.values) {
      if (m.storageValue == v) return m;
    }
    return ReminderMode.fixedInterval;
  }
}
