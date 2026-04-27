import 'dart:convert';

/// Локально и на сервере: имя (`first_name`) + фамилия (`last_name`), опционально.
class PatientProfile {
  const PatientProfile({
    required this.name,
    this.surname = '',
    this.updatedAt,
  });

  final String name;
  final String surname;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => {
        'name': name,
        'surname': surname,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  static PatientProfile fromJson(Map<String, Object?> json) {
    final name = json['name'] as String? ?? json['firstName'] as String? ?? '';
    final surname = json['surname'] as String? ??
        json['lastName'] as String? ??
        json['last_name'] as String? ??
        '';
    return PatientProfile(
      name: name,
      surname: surname,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  static PatientProfile? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
  }

  String toJsonString() => jsonEncode(toJson());
}
