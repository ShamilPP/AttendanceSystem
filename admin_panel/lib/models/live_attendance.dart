import '../utils/json_utils.dart';
import 'attendance.dart';
import 'user.dart';

/// Summary counters on `GET /attendance/live`.
class LiveSummary {
  const LiveSummary({
    this.total = 0,
    this.present = 0,
    this.late = 0,
    this.absent = 0,
    this.onLeave = 0,
    this.checkedOut = 0,
    this.onBreak = 0,
  });

  final int total;
  final int present;
  final int late;
  final int absent;
  final int onLeave;
  final int checkedOut;
  final int onBreak;

  factory LiveSummary.fromJson(dynamic json) {
    final map = jsonMap(json);
    return LiveSummary(
      total: jsonInt(map['total']),
      present: jsonInt(map['present']),
      late: jsonInt(map['late']),
      absent: jsonInt(map['absent']),
      onLeave: jsonInt(map['onLeave']),
      checkedOut: jsonInt(map['checkedOut']),
      onBreak: jsonInt(map['onBreak']),
    );
  }
}

/// One row per active employee on the live board.
class LiveRecord {
  const LiveRecord({
    required this.employee,
    this.attendance,
    this.liveStatus = 'NOT_IN',
  });

  final User employee;
  final Attendance? attendance;
  final String liveStatus; // NOT_IN | WORKING | ON_BREAK | CHECKED_OUT | ON_LEAVE

  factory LiveRecord.fromJson(dynamic json) {
    final map = jsonMap(json);
    return LiveRecord(
      employee: User.fromJson(map['employee']),
      attendance: map['attendance'] == null
          ? null
          : Attendance.fromJson(map['attendance']),
      liveStatus: jsonString(map['liveStatus'], 'NOT_IN'),
    );
  }
}

/// Full `GET /attendance/live` payload.
class LiveAttendance {
  const LiveAttendance({
    required this.date,
    required this.summary,
    required this.records,
  });

  final String date;
  final LiveSummary summary;
  final List<LiveRecord> records;

  factory LiveAttendance.fromJson(dynamic json) {
    final map = jsonMap(json);
    return LiveAttendance(
      date: jsonString(map['date']),
      summary: LiveSummary.fromJson(map['summary']),
      records: jsonList(map['records']).map(LiveRecord.fromJson).toList(),
    );
  }
}
