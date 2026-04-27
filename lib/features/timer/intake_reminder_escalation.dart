import 'dart:convert';

/// Отслеживание цепочки: первое уведомление → +15 мин пациенту → +30 мин опекунам (API).
class IntakeReminderEscalation {
  IntakeReminderEscalation({
    required this.anchorLocal,
    required this.overdueInstant,
    required this.medicationIds,
    required this.dueAtIsoUtcByMedId,
    this.caregiverApiSent = false,
  });

  final DateTime anchorLocal;
  final DateTime overdueInstant;
  final List<String> medicationIds;
  final Map<String, String> dueAtIsoUtcByMedId;
  final bool caregiverApiSent;

  DateTime get caregiverNotifyAt => anchorLocal.add(const Duration(minutes: 30));

  IntakeReminderEscalation copyWith({bool? sent}) {
    return IntakeReminderEscalation(
      anchorLocal: anchorLocal,
      overdueInstant: overdueInstant,
      medicationIds: medicationIds,
      dueAtIsoUtcByMedId: dueAtIsoUtcByMedId,
      caregiverApiSent: sent ?? caregiverApiSent,
    );
  }

  Map<String, Object?> toJson() => {
        'anchorLocal': anchorLocal.toIso8601String(),
        'overdueInstant': overdueInstant.toIso8601String(),
        'medicationIds': medicationIds,
        'dueAtIsoUtc': dueAtIsoUtcByMedId,
        'caregiverApiSent': caregiverApiSent,
      };

  String toJsonString() => jsonEncode(toJson());

  static IntakeReminderEscalation? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final anchor = DateTime.tryParse(m['anchorLocal'] as String? ?? '');
      final overdue = DateTime.tryParse(m['overdueInstant'] as String? ?? '');
      final ids = (m['medicationIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
      final dueRaw = m['dueAtIsoUtc'];
      final dueMap = <String, String>{};
      if (dueRaw is Map) {
        dueRaw.forEach((k, v) {
          dueMap[k.toString()] = v.toString();
        });
      }
      if (anchor == null || overdue == null || ids.isEmpty) return null;
      return IntakeReminderEscalation(
        anchorLocal: anchor,
        overdueInstant: overdue,
        medicationIds: ids,
        dueAtIsoUtcByMedId: dueMap,
        caregiverApiSent: m['caregiverApiSent'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
