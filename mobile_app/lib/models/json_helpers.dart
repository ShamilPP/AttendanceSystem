/// Tolerant JSON parsing helpers shared by all models.
///
/// The API contract defines exact shapes, but these helpers make the models
/// resilient to `null`s and minor type variations (e.g. int vs double).
library;

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String? asStringOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return fallback;
}

/// Parses an ISO-8601 timestamp (or `YYYY-MM-DD` date). Returns null when the
/// value is absent or unparseable.
DateTime? asDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}
