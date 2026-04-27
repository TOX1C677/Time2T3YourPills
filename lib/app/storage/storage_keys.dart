/// Единый реестр ключей локального кэша (GetStorage). Без «магических строк» в коде.
abstract final class StorageKeys {
  static const String medicationsJson = 'cache.medications.v1';
  static const String patientProfileJson = 'cache.patient.v1';
  static const String outboxJson = 'sync.outbox.v1';
  static const String metaLastSyncAt = 'sync.last_sync_at';
  /// UI: весь текст жирным (доступность / паркинсон-дружественный режим).
  static const String uiBoldFonts = 'ui.bold_fonts.v1';

  /// Состояние мульти-таймера: nextDue по id + последняя запланированная группа для уведомления.
  static const String intakeTimerStateJson = 'timer.intake_state.v2';
  @Deprecated('Используйте intakeTimerStateJson')
  static const String timerSessionJson = 'timer.active_session.v1';
}
