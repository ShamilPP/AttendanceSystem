import 'json_helpers.dart';

/// Document types from the contract.
abstract final class DocumentType {
  static const idProof = 'ID_PROOF';
  static const companyId = 'COMPANY_ID';
  static const other = 'OTHER';

  static const all = [idProof, companyId, other];

  static String label(String type) {
    switch (type) {
      case idProof:
        return 'ID Proof';
      case companyId:
        return 'Company ID';
      case other:
        return 'Other';
      default:
        return type;
    }
  }
}

/// Uploaded employee document metadata.
class EmployeeDocument {
  const EmployeeDocument({
    required this.id,
    required this.employee,
    required this.type,
    required this.name,
    required this.fileName,
    this.mimeType = '',
    this.size = 0,
    this.uploadedAt,
  });

  final String id;

  /// Owning user id (bare string in the contract; tolerant of objects).
  final String employee;

  /// `ID_PROOF | COMPANY_ID | OTHER`.
  final String type;
  final String name;
  final String fileName;
  final String mimeType;
  final int size;
  final DateTime? uploadedAt;

  factory EmployeeDocument.fromJson(Map<String, dynamic> json) {
    return EmployeeDocument(
      id: asString(json['_id']),
      employee: json['employee'] is Map
          ? asString(asMap(json['employee'])['_id'])
          : asString(json['employee']),
      type: asString(json['type'], DocumentType.other),
      name: asString(json['name']),
      fileName: asString(json['fileName']),
      mimeType: asString(json['mimeType']),
      size: asInt(json['size']),
      uploadedAt: asDateTime(json['uploadedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'employee': employee,
        'type': type,
        'name': name,
        'fileName': fileName,
        'mimeType': mimeType,
        'size': size,
        'uploadedAt': uploadedAt?.toUtc().toIso8601String(),
      };

  bool get isPdf =>
      mimeType == 'application/pdf' ||
      fileName.toLowerCase().endsWith('.pdf');
}
