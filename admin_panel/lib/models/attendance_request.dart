import '../utils/json_utils.dart';
import 'attendance.dart';

/// Employee-submitted attendance regularization request.
class AttendanceRequest {
  const AttendanceRequest({
    required this.id,
    this.employee,
    required this.date,
    required this.type,
    this.requestedCheckIn,
    this.requestedCheckOut,
    this.reason = '',
    this.status = 'PENDING',
    this.reviewedBy,
    this.reviewNote,
    this.createdAt,
  });

  final String id;
  final EmployeeRef? employee;
  final String date; // YYYY-MM-DD
  final String type; // MISSED_CHECK_IN | MISSED_CHECK_OUT | FULL_DAY | LEAVE
  final DateTime? requestedCheckIn;
  final DateTime? requestedCheckOut;
  final String reason;
  final String status; // PENDING | APPROVED | REJECTED
  final String? reviewedBy;
  final String? reviewNote;
  final DateTime? createdAt;

  String get typeLabel {
    switch (type) {
      case 'MISSED_CHECK_IN':
        return 'Missed check-in';
      case 'MISSED_CHECK_OUT':
        return 'Missed check-out';
      case 'FULL_DAY':
        return 'Full day';
      case 'LEAVE':
        return 'Leave';
      default:
        return type;
    }
  }

  factory AttendanceRequest.fromJson(dynamic json) {
    final map = jsonMap(json);
    return AttendanceRequest(
      id: jsonString(map['_id']),
      employee: EmployeeRef.fromJsonOrNull(map['employee']),
      date: jsonString(map['date']),
      type: jsonString(map['type']),
      requestedCheckIn: jsonDateTime(map['requestedCheckIn']),
      requestedCheckOut: jsonDateTime(map['requestedCheckOut']),
      reason: jsonString(map['reason']),
      status: jsonString(map['status'], 'PENDING'),
      reviewedBy: jsonStringOrNull(map['reviewedBy']),
      reviewNote: jsonStringOrNull(map['reviewNote']),
      createdAt: jsonDateTime(map['createdAt']),
    );
  }
}
