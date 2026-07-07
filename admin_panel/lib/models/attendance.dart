import '../utils/json_utils.dart';
import 'catalog_item.dart';

/// GPS point attached to a check-in/out.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  static GeoPoint? fromJsonOrNull(dynamic json) {
    if (json == null) return null;
    final map = jsonMap(json);
    return GeoPoint(
      latitude: jsonDouble(map['latitude']),
      longitude: jsonDouble(map['longitude']),
    );
  }
}

/// One break interval; `end` may be null while the break is open.
class BreakEntry {
  const BreakEntry({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  factory BreakEntry.fromJson(dynamic json) {
    final map = jsonMap(json);
    return BreakEntry(
      start: jsonDateTime(map['start']),
      end: jsonDateTime(map['end']),
    );
  }
}

/// Admin correction metadata, present only if the record was edited.
class Correction {
  const Correction({this.correctedBy, this.note, this.correctedAt});

  final String? correctedBy;
  final String? note;
  final DateTime? correctedAt;

  static Correction? fromJsonOrNull(dynamic json) {
    if (json == null) return null;
    final map = jsonMap(json);
    return Correction(
      correctedBy: jsonStringOrNull(map['correctedBy']),
      note: jsonStringOrNull(map['note']),
      correctedAt: jsonDateTime(map['correctedAt']),
    );
  }
}

/// The embedded employee summary on attendance records / requests.
class EmployeeRef {
  const EmployeeRef({
    required this.id,
    required this.employeeId,
    required this.name,
    this.department,
  });

  final String id;
  final String employeeId;
  final String name;
  final CatalogItem? department;

  String get departmentName => department?.name ?? '—';

  /// Null-tolerant: accepts a populated object or a bare id string.
  static EmployeeRef? fromJsonOrNull(dynamic json) {
    if (json == null) return null;
    if (json is String) {
      return EmployeeRef(id: json, employeeId: '', name: '');
    }
    final map = jsonMap(json);
    return EmployeeRef(
      id: jsonString(map['_id']),
      employeeId: jsonString(map['employeeId']),
      name: jsonString(map['name']),
      department: CatalogItem.fromJsonOrNull(map['department']),
    );
  }
}

/// Attendance record — one per employee per day.
class Attendance {
  const Attendance({
    required this.id,
    this.employee,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.breaks = const [],
    this.workMinutes = 0,
    this.breakMinutes = 0,
    this.status = 'PRESENT',
    this.isLate = false,
    this.isEarlyOut = false,
    this.checkInLocation,
    this.checkOutLocation,
    this.correction,
  });

  final String id;
  final EmployeeRef? employee;
  final String date; // YYYY-MM-DD
  final DateTime? checkIn;
  final DateTime? checkOut;
  final List<BreakEntry> breaks;
  final int workMinutes;
  final int breakMinutes;
  final String status; // PRESENT | LATE | ABSENT | ON_LEAVE | HALF_DAY
  final bool isLate;
  final bool isEarlyOut;
  final GeoPoint? checkInLocation;
  final GeoPoint? checkOutLocation;
  final Correction? correction;

  factory Attendance.fromJson(dynamic json) {
    final map = jsonMap(json);
    return Attendance(
      id: jsonString(map['_id']),
      employee: EmployeeRef.fromJsonOrNull(map['employee']),
      date: jsonString(map['date']),
      checkIn: jsonDateTime(map['checkIn']),
      checkOut: jsonDateTime(map['checkOut']),
      breaks: jsonList(map['breaks']).map(BreakEntry.fromJson).toList(),
      workMinutes: jsonInt(map['workMinutes']),
      breakMinutes: jsonInt(map['breakMinutes']),
      status: jsonString(map['status'], 'PRESENT'),
      isLate: jsonBool(map['isLate']),
      isEarlyOut: jsonBool(map['isEarlyOut']),
      checkInLocation: GeoPoint.fromJsonOrNull(map['checkInLocation']),
      checkOutLocation: GeoPoint.fromJsonOrNull(map['checkOutLocation']),
      correction: Correction.fromJsonOrNull(map['correction']),
    );
  }
}
