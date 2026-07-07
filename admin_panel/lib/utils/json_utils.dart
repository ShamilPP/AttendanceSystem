/// Null-tolerant JSON accessors used by all models.
library;

String jsonString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

String? jsonStringOrNull(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

int jsonInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double jsonDouble(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool jsonBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) {
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return fallback;
}

DateTime? jsonDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return <String, dynamic>{};
}

List<dynamic> jsonList(dynamic value) {
  if (value is List) return value;
  return const [];
}
