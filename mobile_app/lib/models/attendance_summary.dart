import 'attendance.dart';
import 'json_helpers.dart';

/// Response of `GET /attendance/summary?month=YYYY-MM`.
class AttendanceSummary {
  const AttendanceSummary({
    required this.month,
    this.workingDays = 0,
    this.presentDays = 0,
    this.lateDays = 0,
    this.absentDays = 0,
    this.leaveDays = 0,
    this.halfDays = 0,
    this.totalWorkMinutes = 0,
    this.totalBreakMinutes = 0,
    this.averageWorkMinutes = 0,
    this.earlyOutDays = 0,
    this.records = const [],
  });

  /// `YYYY-MM`.
  final String month;
  final int workingDays;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int leaveDays;
  final int halfDays;
  final int totalWorkMinutes;
  final int totalBreakMinutes;
  final int averageWorkMinutes;
  final int earlyOutDays;
  final List<Attendance> records;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      month: asString(json['month']),
      workingDays: asInt(json['workingDays']),
      presentDays: asInt(json['presentDays']),
      lateDays: asInt(json['lateDays']),
      absentDays: asInt(json['absentDays']),
      leaveDays: asInt(json['leaveDays']),
      halfDays: asInt(json['halfDays']),
      totalWorkMinutes: asInt(json['totalWorkMinutes']),
      totalBreakMinutes: asInt(json['totalBreakMinutes']),
      averageWorkMinutes: asInt(json['averageWorkMinutes']),
      earlyOutDays: asInt(json['earlyOutDays']),
      records: asList(json['records'])
          .map((e) => Attendance.fromJson(asMap(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'workingDays': workingDays,
        'presentDays': presentDays,
        'lateDays': lateDays,
        'absentDays': absentDays,
        'leaveDays': leaveDays,
        'halfDays': halfDays,
        'totalWorkMinutes': totalWorkMinutes,
        'totalBreakMinutes': totalBreakMinutes,
        'averageWorkMinutes': averageWorkMinutes,
        'earlyOutDays': earlyOutDays,
        'records': records.map((r) => r.toJson()).toList(),
      };
}
