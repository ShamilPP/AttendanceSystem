import '../utils/json_utils.dart';

/// One per-row failure in an Excel import.
class ImportRowError {
  const ImportRowError({required this.row, required this.message});

  final int row;
  final String message;

  factory ImportRowError.fromJson(dynamic json) {
    final map = jsonMap(json);
    return ImportRowError(
      row: jsonInt(map['row']),
      message: jsonString(map['message']),
    );
  }
}

/// `POST /employees/import` result.
class ImportResult {
  const ImportResult({
    this.imported = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  final int imported;
  final int skipped;
  final List<ImportRowError> errors;

  factory ImportResult.fromJson(dynamic json) {
    final map = jsonMap(json);
    return ImportResult(
      imported: jsonInt(map['imported']),
      skipped: jsonInt(map['skipped']),
      errors: jsonList(map['errors']).map(ImportRowError.fromJson).toList(),
    );
  }
}
