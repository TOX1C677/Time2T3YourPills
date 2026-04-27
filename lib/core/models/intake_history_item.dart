/// Запись истории приёма с API (`/v1/.../intake-events`).
class IntakeHistoryItem {
  const IntakeHistoryItem({
    required this.id,
    this.medicationId,
    required this.medicationNameSnapshot,
    required this.dosageSnapshot,
    required this.scheduledAt,
    required this.recordedAt,
    required this.status,
    required this.source,
  });

  final String id;
  final String? medicationId;
  final String medicationNameSnapshot;
  final String dosageSnapshot;
  final DateTime scheduledAt;
  final DateTime recordedAt;
  final String status;
  final String source;

  static IntakeHistoryItem fromApiMap(Map<String, dynamic> m) {
    return IntakeHistoryItem(
      id: m['id']?.toString() ?? '',
      medicationId: m['medication_id']?.toString(),
      medicationNameSnapshot: m['medication_name_snapshot'] as String? ?? '',
      dosageSnapshot: m['dosage_snapshot'] as String? ?? '',
      scheduledAt: DateTime.parse(m['scheduled_at'] as String),
      recordedAt: DateTime.parse(m['recorded_at'] as String),
      status: m['status'] as String? ?? '',
      source: m['source'] as String? ?? '',
    );
  }

  String get statusLabelRu {
    switch (status) {
      case 'confirmed':
        return 'Подтверждён';
      case 'missed':
        return 'Пропущен';
      case 'snoozed':
        return 'Отложен';
      default:
        return status;
    }
  }
}
