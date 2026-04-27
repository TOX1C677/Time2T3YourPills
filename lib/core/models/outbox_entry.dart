import 'dart:convert';

class OutboxEntry {
  OutboxEntry({
    required this.id,
    required this.type,
    required this.payloadJson,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String payloadJson;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'payloadJson': payloadJson,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static OutboxEntry fromJson(Map<String, Object?> json) {
    return OutboxEntry(
      id: json['id'] as String,
      type: json['type'] as String,
      payloadJson: json['payloadJson'] as String? ?? '{}',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static List<OutboxEntry> listFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => OutboxEntry.fromJson(Map<String, Object?>.from(e as Map))).toList();
  }

  static String listToJsonString(List<OutboxEntry> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }
}
