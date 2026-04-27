import 'dart:convert';

class PatientProfile {
  const PatientProfile({
    required this.name,
    required this.middleName,
    this.updatedAt,
  });

  final String name;
  final String middleName;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => {
        'name': name,
        'middleName': middleName,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  static PatientProfile fromJson(Map<String, Object?> json) {
    return PatientProfile(
      name: json['name'] as String? ?? '',
      middleName: json['middleName'] as String? ?? '',
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  static PatientProfile? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return PatientProfile.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
  }

  String toJsonString() => jsonEncode(toJson());
}
