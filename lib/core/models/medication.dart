import 'dart:convert';

import 'reminder_mode.dart';

class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.reminderMode,
    this.intervalMinutes,
    this.slotTimes = const [],
    this.firstIntakeHm,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String dosage;
  final ReminderMode reminderMode;
  final int? intervalMinutes;
  final List<String> slotTimes;
  /// Локальное время первого приёма «ЧЧ:ММ» (интервал и график).
  final String? firstIntakeHm;
  final DateTime? updatedAt;

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    ReminderMode? reminderMode,
    int? intervalMinutes,
    List<String>? slotTimes,
    String? firstIntakeHm,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      reminderMode: reminderMode ?? this.reminderMode,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      slotTimes: slotTimes ?? this.slotTimes,
      firstIntakeHm: firstIntakeHm ?? this.firstIntakeHm,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    final f = firstIntakeHm;
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'reminderMode': reminderMode.storageValue,
      'intervalMinutes': intervalMinutes,
      'slotTimes': slotTimes,
      if (f != null && f.isNotEmpty) 'firstIntakeHm': f,
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  static Medication fromJson(Map<String, Object?> json) {
    final firstRaw = json['firstIntakeHm'] ?? json['first_intake_time'];
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      reminderMode: ReminderMode.fromStorage(json['reminderMode'] as String?),
      intervalMinutes: (json['intervalMinutes'] as num?)?.toInt(),
      slotTimes: (json['slotTimes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      firstIntakeHm: firstRaw is String && firstRaw.isNotEmpty ? firstRaw : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  static List<Medication> listFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Medication.fromJson(Map<String, Object?>.from(e as Map))).toList();
  }

  static String listToJsonString(List<Medication> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }
}
