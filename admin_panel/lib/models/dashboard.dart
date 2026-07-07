import '../utils/json_utils.dart';

/// `GET /dashboard/stats` payload.
class DashboardStats {
  const DashboardStats({
    this.totalEmployees = 0,
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.onLeave = 0,
    this.onBreak = 0,
    this.checkedOut = 0,
    this.averageWorkMinutes = 0,
    this.attendanceRate = 0,
  });

  final int totalEmployees;
  final int present;
  final int absent;
  final int late;
  final int onLeave;
  final int onBreak;
  final int checkedOut;
  final int averageWorkMinutes;
  final double attendanceRate; // 0-100

  factory DashboardStats.fromJson(dynamic json) {
    final map = jsonMap(json);
    return DashboardStats(
      totalEmployees: jsonInt(map['totalEmployees']),
      present: jsonInt(map['present']),
      absent: jsonInt(map['absent']),
      late: jsonInt(map['late']),
      onLeave: jsonInt(map['onLeave']),
      onBreak: jsonInt(map['onBreak']),
      checkedOut: jsonInt(map['checkedOut']),
      averageWorkMinutes: jsonInt(map['averageWorkMinutes']),
      attendanceRate: jsonDouble(map['attendanceRate']),
    );
  }
}

/// One point in `GET /dashboard/trends`.
class TrendPoint {
  const TrendPoint({
    required this.label,
    this.present = 0,
    this.late = 0,
    this.absent = 0,
  });

  final String label; // YYYY-MM-DD | 2026-W27 | 2026-07
  final int present;
  final int late;
  final int absent;

  factory TrendPoint.fromJson(dynamic json) {
    final map = jsonMap(json);
    return TrendPoint(
      label: jsonString(map['label']),
      present: jsonInt(map['present']),
      late: jsonInt(map['late']),
      absent: jsonInt(map['absent']),
    );
  }
}
