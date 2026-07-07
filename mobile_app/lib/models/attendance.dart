import 'json_helpers.dart';
import 'user.dart';

/// Attendance scan actions accepted by `POST /attendance/scan`.
enum AttendanceAction {
  checkIn('CHECK_IN', 'Check In'),
  checkOut('CHECK_OUT', 'Check Out'),
  breakStart('BREAK_START', 'Start Break'),
  breakEnd('BREAK_END', 'End Break');

  const AttendanceAction(this.apiValue, this.label);

  /// Exact enum value sent to the API.
  final String apiValue;
  final String label;
}

/// Attendance status values from the contract.
abstract final class AttendanceStatus {
  static const present = 'PRESENT';
  static const late = 'LATE';
  static const absent = 'ABSENT';
  static const onLeave = 'ON_LEAVE';
  static const halfDay = 'HALF_DAY';
}

/// One break interval; `end` is null while the break is open.
class BreakEntry {
  const BreakEntry({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  bool get isOpen => start != null && end == null;

  Duration duration(DateTime now) {
    final s = start;
    if (s == null) return Duration.zero;
    final e = end ?? now;
    final d = e.difference(s);
    return d.isNegative ? Duration.zero : d;
  }

  factory BreakEntry.fromJson(Map<String, dynamic> json) => BreakEntry(
        start: asDateTime(json['start']),
        end: asDateTime(json['end']),
      );

  Map<String, dynamic> toJson() => {
        'start': start?.toUtc().toIso8601String(),
        'end': end?.toUtc().toIso8601String(),
      };
}

/// `{ latitude, longitude }` pair.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        latitude: asDouble(json['latitude']),
        longitude: asDouble(json['longitude']),
      );

  Map<String, dynamic> toJson() =>
      {'latitude': latitude, 'longitude': longitude};
}

/// Admin-correction metadata, present only when an admin edited the record.
class AttendanceCorrection {
  const AttendanceCorrection({this.correctedBy, this.note, this.correctedAt});

  final String? correctedBy;
  final String? note;
  final DateTime? correctedAt;

  factory AttendanceCorrection.fromJson(Map<String, dynamic> json) =>
      AttendanceCorrection(
        correctedBy: json['correctedBy'] is Map
            ? asStringOrNull(asMap(json['correctedBy'])['_id'])
            : asStringOrNull(json['correctedBy']),
        note: asStringOrNull(json['note']),
        correctedAt: asDateTime(json['correctedAt']),
      );

  Map<String, dynamic> toJson() => {
        'correctedBy': correctedBy,
        'note': note,
        'correctedAt': correctedAt?.toUtc().toIso8601String(),
      };
}

/// The embedded employee snippet on an attendance record.
class AttendanceEmployee {
  const AttendanceEmployee({
    required this.id,
    this.employeeId = '',
    this.name = '',
    this.department,
  });

  final String id;
  final String employeeId;
  final String name;
  final NamedRef? department;

  /// Accepts a populated object or a bare id string.
  factory AttendanceEmployee.fromJsonValue(dynamic value) {
    if (value is String) return AttendanceEmployee(id: value);
    final map = asMap(value);
    return AttendanceEmployee(
      id: asString(map['_id']),
      employeeId: asString(map['employeeId']),
      name: asString(map['name']),
      department: map['department'] == null
          ? null
          : NamedRef.fromJsonValue(map['department']),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'employeeId': employeeId,
        'name': name,
        'department': department?.toJson(),
      };
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
    this.status = AttendanceStatus.present,
    this.isLate = false,
    this.isEarlyOut = false,
    this.checkInLocation,
    this.checkOutLocation,
    this.correction,
  });

  final String id;
  final AttendanceEmployee? employee;

  /// Calendar day string `YYYY-MM-DD`.
  final String date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final List<BreakEntry> breaks;

  /// Work minutes excluding breaks, computed by the server.
  final int workMinutes;
  final int breakMinutes;

  /// `PRESENT | LATE | ABSENT | ON_LEAVE | HALF_DAY`.
  final String status;
  final bool isLate;
  final bool isEarlyOut;
  final GeoPoint? checkInLocation;
  final GeoPoint? checkOutLocation;
  final AttendanceCorrection? correction;

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: asString(json['_id']),
      employee: json['employee'] == null
          ? null
          : AttendanceEmployee.fromJsonValue(json['employee']),
      date: asString(json['date']),
      checkIn: asDateTime(json['checkIn']),
      checkOut: asDateTime(json['checkOut']),
      breaks: asList(json['breaks'])
          .map((e) => BreakEntry.fromJson(asMap(e)))
          .toList(),
      workMinutes: asInt(json['workMinutes']),
      breakMinutes: asInt(json['breakMinutes']),
      status: asString(json['status'], AttendanceStatus.present),
      isLate: asBool(json['isLate']),
      isEarlyOut: asBool(json['isEarlyOut']),
      checkInLocation: json['checkInLocation'] == null
          ? null
          : GeoPoint.fromJson(asMap(json['checkInLocation'])),
      checkOutLocation: json['checkOutLocation'] == null
          ? null
          : GeoPoint.fromJson(asMap(json['checkOutLocation'])),
      correction: json['correction'] == null
          ? null
          : AttendanceCorrection.fromJson(asMap(json['correction'])),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'employee': employee?.toJson(),
        'date': date,
        'checkIn': checkIn?.toUtc().toIso8601String(),
        'checkOut': checkOut?.toUtc().toIso8601String(),
        'breaks': breaks.map((b) => b.toJson()).toList(),
        'workMinutes': workMinutes,
        'breakMinutes': breakMinutes,
        'status': status,
        'isLate': isLate,
        'isEarlyOut': isEarlyOut,
        'checkInLocation': checkInLocation?.toJson(),
        'checkOutLocation': checkOutLocation?.toJson(),
        'correction': correction?.toJson(),
      };

  bool get hasOpenBreak => breaks.any((b) => b.isOpen);

  BreakEntry? get openBreak {
    for (final b in breaks.reversed) {
      if (b.isOpen) return b;
    }
    return null;
  }

  /// Total break time; open breaks count up to [now] (or check-out).
  Duration liveBreakDuration(DateTime now) {
    var total = Duration.zero;
    for (final b in breaks) {
      final start = b.start;
      if (start == null) continue;
      final end = b.end ?? checkOut ?? now;
      final d = end.difference(start);
      if (!d.isNegative) total += d;
    }
    return total;
  }

  /// Worked time excluding breaks; live-ticking while checked in.
  Duration liveWorkDuration(DateTime now) {
    final start = checkIn;
    if (start == null) return Duration.zero;
    if (checkOut != null) return Duration(minutes: workMinutes);
    final d = now.difference(start) - liveBreakDuration(now);
    return d.isNegative ? Duration.zero : d;
  }
}
