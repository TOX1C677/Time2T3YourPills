/// Единый реестр ключей локального кэша (GetStorage). Без «магических строк» в коде.
abstract final class StorageKeys {
  /// Старый общий ключ (до изоляции по аккаунту) - удаляется при [clearUserBoundLocalCache].
  static const String medicationsJson = 'cache.medications.v1';
  static const String patientProfileJson = 'cache.patient.v1';
  static const String outboxJson = 'sync.outbox.v1';

  static String _accountSegment(String? email, String? role, [String? extra]) {
    final e = (email ?? '').trim().toLowerCase();
    final r = (role ?? 'none').trim().toLowerCase();
    final x = (extra ?? '').trim();
    final raw = x.isEmpty ? '$e|$r' : '$e|$r|$x';
    return raw.replaceAll(RegExp(r'[^\w@\|.^-]'), '_');
  }

  /// Кэш препаратов строго по сессии: пациент - по почте+роли; опекун - ещё и по выбранному `patient_user_id`.
  static String medicationsCacheKey({
    required String? email,
    required String? role,
    String? caregiverPatientId,
  }) {
    final r = (role ?? '').trim().toLowerCase();
    final seg = r == 'caregiver'
        ? _accountSegment(email, role, caregiverPatientId)
        : _accountSegment(email, role);
    return 'cache.medications.v3.$seg';
  }

  static String patientProfileCacheKey({required String? email, required String? role}) {
    return 'cache.patient.v3.${_accountSegment(email, role)}';
  }

  static String outboxCacheKey({required String? email, required String? role}) {
    return 'sync.outbox.v3.${_accountSegment(email, role)}';
  }
  static const String metaLastSyncAt = 'sync.last_sync_at';
  /// UI: весь текст жирным (доступность / паркинсон-дружественный режим).
  static const String uiBoldFonts = 'ui.bold_fonts.v1';

  /// Состояние мульти-таймера: nextDue по id + последняя запланированная группа для уведомления.
  static const String intakeTimerStateJson = 'timer.intake_state.v2';

  /// Якорь цепочки напоминаний (0 / +15 мин пациент / +30 мин опекуны через API).
  static const String intakeReminderEscalationJson = 'timer.reminder_escalation.v1';
  @Deprecated('Используйте intakeTimerStateJson')
  static const String timerSessionJson = 'timer.active_session.v1';
}
