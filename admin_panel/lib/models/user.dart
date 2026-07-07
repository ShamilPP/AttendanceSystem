import '../utils/json_utils.dart';
import 'catalog_item.dart';

/// User (employee or admin) — see API contract "Core objects".
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
  });

  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String role; // 'admin' | 'employee'
  final CatalogItem? department;
  final CatalogItem? designation;
  final String? phone;
  final String? address;
  final String? joiningDate; // YYYY-MM-DD
  final bool isActive;
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin';
  String get departmentName => department?.name ?? '—';
  String get designationName => designation?.name ?? '—';

  factory User.fromJson(dynamic json) {
    final map = jsonMap(json);
    return User(
      id: jsonString(map['_id']),
      employeeId: jsonString(map['employeeId']),
      name: jsonString(map['name']),
      email: jsonString(map['email']),
      role: jsonString(map['role'], 'employee'),
      department: CatalogItem.fromJsonOrNull(map['department']),
      designation: CatalogItem.fromJsonOrNull(map['designation']),
      phone: jsonStringOrNull(map['phone']),
      address: jsonStringOrNull(map['address']),
      joiningDate: jsonStringOrNull(map['joiningDate']),
      isActive: jsonBool(map['isActive'], true),
      createdAt: jsonDateTime(map['createdAt']),
    );
  }
}
