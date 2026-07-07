import 'attendance.dart';
import 'json_helpers.dart';

/// Attendance-request (regularization) types from the contract.
abstract final class AttendanceRequestType {
  static const missedCheckIn = 'MISSED_CHECK_IN';
  static const missedCheckOut = 'MISSED_CHECK_OUT';
  static const fullDay = 'FULL_DAY';
  static const leave = 'LEAVE';

  static const all = [missedCheckIn, missedCheckOut, fullDay, leave];

  static String label(String type) {
    switch (type) {
      case missedCheckIn:
        return 'Missed Check-In';
      case missedCheckOut:
        return 'Missed Check-Out';
      case fullDay:
        return 'Full Day';
      case leave:
        return 'Leave';
      default:
        return type;
    }
  }
}

/// Attendance-request statuses from the contract.
abstract final class AttendanceRequestStatus {
  static const pending = 'PENDING';
  static const approved = 'APPROVED';
  static const rejected = 'REJECTED';
}

/// Employee-submitted attendance regularization request.
class AttendanceRequest {
  const AttendanceRequest({
    required this.id,
    this.employee,
    required this.date,
    required this.type,
    this.requestedCheckIn,
    this.requestedCheckOut,
    required this.reason,
    this.status = AttendanceRequestStatus.pending,
    this.reviewedBy,
    this.reviewNote,
    this.createdAt,
  });

  final String id;
  final AttendanceEmployee? employee;

  /// Calendar day string `YYYY-MM-DD`.
  final String date;

  /// `MISSED_CHECK_IN | MISSED_CHECK_OUT | FULL_DAY | LEAVE`.
  final String type;
  final DateTime? requestedCheckIn;
  final DateTime? requestedCheckOut;
  final String reason;

  /// `PENDING | APPROVED | REJECTED`.
  final String status;
  final String? reviewedBy;
  final String? reviewNote;
  final DateTime? createdAt;

  factory AttendanceRequest.fromJson(Map<String, dynamic> json) {
    return AttendanceRequest(
      id: asString(json['_id']),
      employee: json['employee'] == null
          ? null
          : AttendanceEmployee.fromJsonValue(json['employee']),
      date: asString(json['date']),
      type: asString(json['type']),
      requestedCheckIn: asDateTime(json['requestedCheckIn']),
      requestedCheckOut: asDateTime(json['requestedCheckOut']),
      reason: asString(json['reason']),
      status: asString(json['status'], AttendanceRequestStatus.pending),
      reviewedBy: json['reviewedBy'] is Map
          ? asStringOrNull(asMap(json['reviewedBy'])['name'] ??
              asMap(json['reviewedBy'])['_id'])
          : asStringOrNull(json['reviewedBy']),
      reviewNote: asStringOrNull(json['reviewNote']),
      createdAt: asDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'employee': employee?.toJson(),
        'date': date,
        'type': type,
        'requestedCheckIn': requestedCheckIn?.toUtc().toIso8601String(),
        'requestedCheckOut': requestedCheckOut?.toUtc().toIso8601String(),
        'reason': reason,
        'status': status,
        'reviewedBy': reviewedBy,
        'reviewNote': reviewNote,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };
}
