import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_mobile/models/attendance.dart';
import 'package:attendance_mobile/models/attendance_request.dart';
import 'package:attendance_mobile/models/attendance_summary.dart';
import 'package:attendance_mobile/models/document.dart';
import 'package:attendance_mobile/models/user.dart';

/// Contract-shaped fixtures (docs/API_CONTRACT.md).
const String userFixture = '''
{
  "_id": "665f1c2ab8d3f60012aa0001",
  "employeeId": "EMP-0001",
  "name": "Jane Doe",
  "email": "jane@company.com",
  "role": "employee",
  "department": { "_id": "665f1c2ab8d3f60012aa0d01", "name": "Engineering" },
  "designation": { "_id": "665f1c2ab8d3f60012aa0e01", "name": "Software Engineer" },
  "phone": "+971500000000",
  "address": "Dubai Marina, Dubai",
  "joiningDate": "2025-01-15",
  "isActive": true,
  "createdAt": "2025-01-15T08:00:00.000Z",
  "updatedAt": "2026-07-01T10:30:00.000Z"
}
''';

const String attendanceFixture = '''
{
  "_id": "665f1c2ab8d3f60012aa1001",
  "employee": {
    "_id": "665f1c2ab8d3f60012aa0001",
    "employeeId": "EMP-0001",
    "name": "Jane Doe",
    "department": { "_id": "665f1c2ab8d3f60012aa0d01", "name": "Engineering" }
  },
  "date": "2026-07-07",
  "checkIn": "2026-07-07T04:05:00.000Z",
  "checkOut": "2026-07-07T13:02:00.000Z",
  "breaks": [
    { "start": "2026-07-07T08:00:00.000Z", "end": "2026-07-07T08:30:00.000Z" }
  ],
  "workMinutes": 508,
  "breakMinutes": 30,
  "status": "PRESENT",
  "isLate": false,
  "isEarlyOut": false,
  "checkInLocation": { "latitude": 25.1972, "longitude": 55.2744 },
  "checkOutLocation": { "latitude": 25.1972, "longitude": 55.2744 },
  "correction": {
    "correctedBy": "665f1c2ab8d3f60012aa0999",
    "note": "Fixed missing check-out",
    "correctedAt": "2026-07-08T06:00:00.000Z"
  }
}
''';

const String openAttendanceFixture = '''
{
  "_id": "665f1c2ab8d3f60012aa1002",
  "employee": "665f1c2ab8d3f60012aa0001",
  "date": "2026-07-07",
  "checkIn": "2026-07-07T04:05:00.000Z",
  "checkOut": null,
  "breaks": [ { "start": "2026-07-07T08:00:00.000Z", "end": null } ],
  "workMinutes": 0,
  "breakMinutes": 0,
  "status": "LATE",
  "isLate": true,
  "isEarlyOut": false,
  "checkInLocation": { "latitude": 25.1972, "longitude": 55.2744 },
  "checkOutLocation": null
}
''';

const String summaryFixture = '''
{
  "month": "2026-07",
  "workingDays": 23,
  "presentDays": 20,
  "lateDays": 3,
  "absentDays": 2,
  "leaveDays": 1,
  "halfDays": 0,
  "totalWorkMinutes": 9700,
  "totalBreakMinutes": 610,
  "averageWorkMinutes": 485,
  "earlyOutDays": 1,
  "records": [$attendanceFixture]
}
''';

const String requestFixture = '''
{
  "_id": "665f1c2ab8d3f60012aa2001",
  "employee": {
    "_id": "665f1c2ab8d3f60012aa0001",
    "employeeId": "EMP-0001",
    "name": "Jane Doe"
  },
  "date": "2026-07-05",
  "type": "MISSED_CHECK_IN",
  "requestedCheckIn": "2026-07-05T04:00:00.000Z",
  "requestedCheckOut": null,
  "reason": "Forgot to scan",
  "status": "PENDING",
  "reviewedBy": null,
  "reviewNote": null,
  "createdAt": "2026-07-05T10:00:00.000Z"
}
''';

const String documentFixture = '''
{
  "_id": "665f1c2ab8d3f60012aa3001",
  "employee": "665f1c2ab8d3f60012aa0001",
  "type": "ID_PROOF",
  "name": "Passport",
  "fileName": "passport.pdf",
  "mimeType": "application/pdf",
  "size": 123456,
  "uploadedAt": "2026-06-01T09:15:00.000Z"
}
''';

Map<String, dynamic> decode(String fixture) =>
    jsonDecode(fixture) as Map<String, dynamic>;

void main() {
  group('User', () {
    test('fromJson parses the contract fixture exactly', () {
      final user = User.fromJson(decode(userFixture));
      expect(user.id, '665f1c2ab8d3f60012aa0001');
      expect(user.employeeId, 'EMP-0001');
      expect(user.name, 'Jane Doe');
      expect(user.email, 'jane@company.com');
      expect(user.role, 'employee');
      expect(user.department?.id, '665f1c2ab8d3f60012aa0d01');
      expect(user.department?.name, 'Engineering');
      expect(user.designation?.name, 'Software Engineer');
      expect(user.phone, '+971500000000');
      expect(user.address, 'Dubai Marina, Dubai');
      expect(user.joiningDate, '2025-01-15');
      expect(user.isActive, isTrue);
      expect(user.createdAt, DateTime.utc(2025, 1, 15, 8));
      expect(user.firstName, 'Jane');
      expect(user.initials, 'JD');
    });

    test('round-trips through toJson', () {
      final original = User.fromJson(decode(userFixture));
      final reparsed = User.fromJson(original.toJson());
      expect(reparsed.toJson(), original.toJson());
      expect(reparsed.joiningDate, '2025-01-15');
      expect(reparsed.updatedAt, DateTime.utc(2026, 7, 1, 10, 30));
    });

    test('is tolerant of missing/null fields', () {
      final user = User.fromJson(const {'_id': 'x'});
      expect(user.id, 'x');
      expect(user.name, '');
      expect(user.department, isNull);
      expect(user.designation, isNull);
      expect(user.joiningDate, isNull);
      expect(user.isActive, isTrue);
    });
  });

  group('Attendance', () {
    test('fromJson parses the contract fixture exactly', () {
      final a = Attendance.fromJson(decode(attendanceFixture));
      expect(a.id, '665f1c2ab8d3f60012aa1001');
      expect(a.employee?.id, '665f1c2ab8d3f60012aa0001');
      expect(a.employee?.employeeId, 'EMP-0001');
      expect(a.employee?.name, 'Jane Doe');
      expect(a.employee?.department?.name, 'Engineering');
      expect(a.date, '2026-07-07');
      expect(a.checkIn, DateTime.utc(2026, 7, 7, 4, 5));
      expect(a.checkOut, DateTime.utc(2026, 7, 7, 13, 2));
      expect(a.breaks, hasLength(1));
      expect(a.breaks.first.start, DateTime.utc(2026, 7, 7, 8));
      expect(a.breaks.first.end, DateTime.utc(2026, 7, 7, 8, 30));
      expect(a.workMinutes, 508);
      expect(a.breakMinutes, 30);
      expect(a.status, AttendanceStatus.present);
      expect(a.isLate, isFalse);
      expect(a.isEarlyOut, isFalse);
      expect(a.checkInLocation?.latitude, 25.1972);
      expect(a.checkInLocation?.longitude, 55.2744);
      expect(a.correction?.correctedBy, '665f1c2ab8d3f60012aa0999');
      expect(a.correction?.note, 'Fixed missing check-out');
      expect(a.hasOpenBreak, isFalse);
    });

    test('round-trips through toJson', () {
      final original = Attendance.fromJson(decode(attendanceFixture));
      final reparsed = Attendance.fromJson(original.toJson());
      expect(reparsed.toJson(), original.toJson());
      // Timestamps stay ISO-8601 UTC strings through the round trip.
      expect(reparsed.toJson()['checkIn'], '2026-07-07T04:05:00.000Z');
      expect(reparsed.toJson()['date'], '2026-07-07');
    });

    test('handles open records (null checkOut, open break)', () {
      final a = Attendance.fromJson(decode(openAttendanceFixture));
      expect(a.checkOut, isNull);
      expect(a.status, AttendanceStatus.late);
      expect(a.isLate, isTrue);
      expect(a.hasOpenBreak, isTrue);
      expect(a.openBreak, isNotNull);
      expect(a.checkOutLocation, isNull);
      // Bare-string employee id is tolerated.
      expect(a.employee?.id, '665f1c2ab8d3f60012aa0001');

      // Live durations: at 09:00 UTC, worked = (09:00-04:05) - 1h open break.
      final now = DateTime.utc(2026, 7, 7, 9);
      expect(a.liveBreakDuration(now), const Duration(hours: 1));
      expect(a.liveWorkDuration(now),
          const Duration(hours: 3, minutes: 55));
    });

    test('closed records report server-computed work minutes', () {
      final a = Attendance.fromJson(decode(attendanceFixture));
      final now = DateTime.utc(2026, 7, 8);
      expect(a.liveWorkDuration(now), const Duration(minutes: 508));
      expect(a.liveBreakDuration(now), const Duration(minutes: 30));
    });

    test('is tolerant of an entirely empty object', () {
      final a = Attendance.fromJson(const {});
      expect(a.id, '');
      expect(a.checkIn, isNull);
      expect(a.breaks, isEmpty);
      expect(a.workMinutes, 0);
      expect(a.status, AttendanceStatus.present);
      expect(a.liveWorkDuration(DateTime.now()), Duration.zero);
    });

    test('scan actions map to the contract enum values', () {
      expect(AttendanceAction.checkIn.apiValue, 'CHECK_IN');
      expect(AttendanceAction.checkOut.apiValue, 'CHECK_OUT');
      expect(AttendanceAction.breakStart.apiValue, 'BREAK_START');
      expect(AttendanceAction.breakEnd.apiValue, 'BREAK_END');
    });
  });

  group('AttendanceSummary', () {
    test('fromJson parses the contract fixture exactly', () {
      final s = AttendanceSummary.fromJson(decode(summaryFixture));
      expect(s.month, '2026-07');
      expect(s.workingDays, 23);
      expect(s.presentDays, 20);
      expect(s.lateDays, 3);
      expect(s.absentDays, 2);
      expect(s.leaveDays, 1);
      expect(s.halfDays, 0);
      expect(s.totalWorkMinutes, 9700);
      expect(s.totalBreakMinutes, 610);
      expect(s.averageWorkMinutes, 485);
      expect(s.earlyOutDays, 1);
      expect(s.records, hasLength(1));
      expect(s.records.first.workMinutes, 508);
    });

    test('round-trips through toJson', () {
      final original = AttendanceSummary.fromJson(decode(summaryFixture));
      final reparsed = AttendanceSummary.fromJson(original.toJson());
      expect(reparsed.toJson(), original.toJson());
    });

    test('is tolerant of missing fields', () {
      final s = AttendanceSummary.fromJson(const {'month': '2026-01'});
      expect(s.month, '2026-01');
      expect(s.workingDays, 0);
      expect(s.records, isEmpty);
    });
  });

  group('AttendanceRequest', () {
    test('fromJson parses the contract fixture exactly', () {
      final r = AttendanceRequest.fromJson(decode(requestFixture));
      expect(r.id, '665f1c2ab8d3f60012aa2001');
      expect(r.employee?.employeeId, 'EMP-0001');
      expect(r.date, '2026-07-05');
      expect(r.type, AttendanceRequestType.missedCheckIn);
      expect(r.requestedCheckIn, DateTime.utc(2026, 7, 5, 4));
      expect(r.requestedCheckOut, isNull);
      expect(r.reason, 'Forgot to scan');
      expect(r.status, AttendanceRequestStatus.pending);
      expect(r.reviewedBy, isNull);
      expect(r.reviewNote, isNull);
      expect(r.createdAt, DateTime.utc(2026, 7, 5, 10));
    });

    test('round-trips through toJson', () {
      final original = AttendanceRequest.fromJson(decode(requestFixture));
      final reparsed = AttendanceRequest.fromJson(original.toJson());
      expect(reparsed.toJson(), original.toJson());
      expect(reparsed.toJson()['requestedCheckIn'],
          '2026-07-05T04:00:00.000Z');
    });

    test('type labels cover every contract value', () {
      for (final type in AttendanceRequestType.all) {
        expect(AttendanceRequestType.label(type), isNot(type));
        expect(AttendanceRequestType.label(type), isNotEmpty);
      }
    });
  });

  group('EmployeeDocument', () {
    test('fromJson parses the contract fixture exactly', () {
      final d = EmployeeDocument.fromJson(decode(documentFixture));
      expect(d.id, '665f1c2ab8d3f60012aa3001');
      expect(d.employee, '665f1c2ab8d3f60012aa0001');
      expect(d.type, DocumentType.idProof);
      expect(d.name, 'Passport');
      expect(d.fileName, 'passport.pdf');
      expect(d.mimeType, 'application/pdf');
      expect(d.size, 123456);
      expect(d.uploadedAt, DateTime.utc(2026, 6, 1, 9, 15));
      expect(d.isPdf, isTrue);
    });

    test('round-trips through toJson', () {
      final original = EmployeeDocument.fromJson(decode(documentFixture));
      final reparsed = EmployeeDocument.fromJson(original.toJson());
      expect(reparsed.toJson(), original.toJson());
    });

    test('is tolerant of missing fields', () {
      final d = EmployeeDocument.fromJson(const {'_id': 'x'});
      expect(d.id, 'x');
      expect(d.size, 0);
      expect(d.uploadedAt, isNull);
      expect(d.type, DocumentType.other);
    });
  });
}
