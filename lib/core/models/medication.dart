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
    this.updatedAt,
  });

  final String id;
  final String name;
  final String dosage;
  final ReminderMode reminderMode;
  final int? intervalMinutes;
  final List<String> slotTimes;
  final DateTime? updatedAt;

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    ReminderMode? reminderMode,
    int? intervalMinutes,
    List<String>? slotTimes,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      reminderMode: reminderMode ?? this.reminderMode,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      slotTimes: slotTimes ?? this.slotTimes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'reminderMode': reminderMode.storageValue,
        'intervalMinutes': intervalMinutes,
        'slotTimes': slotTimes,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  static Medication fromJson(Map<String, Object?> json) {
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      reminderMode: ReminderMode.fromStorage(json['reminderMode'] as String?),
      intervalMinutes: (json['intervalMinutes'] as num?)?.toInt(),
      slotTimes: (json['slotTimes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
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
