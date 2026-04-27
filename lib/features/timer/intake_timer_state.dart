import 'dart:convert';

/// Снимок состояния мульти-таймера для GetStorage.
class IntakeTimerState {
  IntakeTimerState({
    required this.nextDueById,
    this.lastScheduledAt,
    this.lastScheduledMedIds = const [],
  });

  final Map<String, DateTime> nextDueById;
  final DateTime? lastScheduledAt;
  final List<String> lastScheduledMedIds;

  Map<String, Object?> toJson() => {
        'nextDue': nextDueById.map((k, v) => MapEntry(k, v.toUtc().toIso8601String())),
        'lastScheduledAt': lastScheduledAt?.toUtc().toIso8601String(),
        'lastScheduledMedIds': lastScheduledMedIds,
      };

  static IntakeTimerState fromJson(Map<String, Object?> json) {
    final rawNext = json['nextDue'];
    final next = <String, DateTime>{};
    if (rawNext is Map) {
      rawNext.forEach((k, v) {
        final t = DateTime.tryParse(v.toString());
        if (t != null) next[k.toString()] = t.toLocal();
      });
    }
    final at = json['lastScheduledAt'] != null ? DateTime.tryParse(json['lastScheduledAt'] as String) : null;
    final ids = (json['lastScheduledMedIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return IntakeTimerState(
      nextDueById: next,
      lastScheduledAt: at?.toLocal(),
      lastScheduledMedIds: ids,
    );
  }

  static IntakeTimerState empty() => IntakeTimerState(nextDueById: {});

  static IntakeTimerState? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return IntakeTimerState.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
  }

  String toJsonString() => jsonEncode(toJson());
}
