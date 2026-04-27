/// Пропуск приёма для опекуна (`GET /v1/caregiver/alerts`).
class MissedIntakeAlert {
  const MissedIntakeAlert({
    required this.id,
    required this.patientUserId,
    required this.patientDisplayName,
    required this.medicationId,
    required this.medicationName,
    required this.dueAt,
    required this.detectedAt,
  });

  final String id;
  final String patientUserId;
  final String patientDisplayName;
  final String medicationId;
  final String medicationName;
  final DateTime dueAt;
  final DateTime detectedAt;

  static MissedIntakeAlert fromApiMap(Map<String, dynamic> m) {
    return MissedIntakeAlert(
      id: m['id']?.toString() ?? '',
      patientUserId: m['patient_user_id']?.toString() ?? '',
      patientDisplayName: m['patient_display_name'] as String? ?? '',
      medicationId: m['medication_id']?.toString() ?? '',
      medicationName: m['medication_name'] as String? ?? '',
      dueAt: DateTime.parse(m['due_at'] as String),
      detectedAt: DateTime.parse(m['detected_at'] as String),
    );
  }
}
