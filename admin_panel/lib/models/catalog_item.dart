import '../utils/json_utils.dart';

/// A department or designation: `{ _id, name, description? }`.
class CatalogItem {
  const CatalogItem({required this.id, required this.name, this.description});

  final String id;
  final String name;
  final String? description;

  /// Null-tolerant: accepts a populated object or a bare id string.
  static CatalogItem? fromJsonOrNull(dynamic json) {
    if (json == null) return null;
    if (json is String) return CatalogItem(id: json, name: '');
    final map = jsonMap(json);
    return CatalogItem(
      id: jsonString(map['_id']),
      name: jsonString(map['name']),
      description: jsonStringOrNull(map['description']),
    );
  }

  factory CatalogItem.fromJson(dynamic json) =>
      fromJsonOrNull(json) ?? const CatalogItem(id: '', name: '');
}
