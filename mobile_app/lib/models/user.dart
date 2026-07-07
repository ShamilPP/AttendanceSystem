import 'json_helpers.dart';

/// A populated `{ _id, name }` reference (department / designation).
class NamedRef {
  const NamedRef({required this.id, required this.name});

  final String id;
  final String name;

  /// Accepts either a populated object or a bare id string.
  factory NamedRef.fromJsonValue(dynamic value) {
    if (value is String) return NamedRef(id: value, name: '');
    final map = asMap(value);
    return NamedRef(
      id: asString(map['_id']),
      name: asString(map['name']),
    );
  }

  Map<String, dynamic> toJson() => {'_id': id, 'name': name};
}

/// User object as defined by the API contract (employee or admin).
class User {
  const User({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.role,
    this.department,
    this.designation,
    this.phone,
    this.address,
    this.joiningDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String role; // 'admin' | 'employee'
  final NamedRef? department;
  final NamedRef? designation;
  final String? phone;
  final String? address;

  /// Calendar day string `YYYY-MM-DD`.
  final String? joiningDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: asString(json['_id']),
      employeeId: asString(json['employeeId']),
      name: asString(json['name']),
      email: asString(json['email']),
      role: asString(json['role'], 'employee'),
      department: json['department'] == null
          ? null
          : NamedRef.fromJsonValue(json['department']),
      designation: json['designation'] == null
          ? null
          : NamedRef.fromJsonValue(json['designation']),
      phone: asStringOrNull(json['phone']),
      address: asStringOrNull(json['address']),
      joiningDate: asStringOrNull(json['joiningDate']),
      isActive: asBool(json['isActive'], true),
      createdAt: asDateTime(json['createdAt']),
      updatedAt: asDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'employeeId': employeeId,
        'name': name,
        'email': email,
        'role': role,
        'department': department?.toJson(),
        'designation': designation?.toJson(),
        'phone': phone,
        'address': address,
        'joiningDate': joiningDate,
        'isActive': isActive,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
