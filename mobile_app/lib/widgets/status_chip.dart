import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../models/attendance_request.dart';
import '../utils/formatters.dart';

/// Contract-defined colors for attendance statuses.
Color attendanceStatusColor(String status) {
  switch (status) {
    case AttendanceStatus.present:
      return const Color(0xFF2E7D32); // green
    case AttendanceStatus.late:
      return const Color(0xFFEF6C00); // orange
    case AttendanceStatus.absent:
      return const Color(0xFFC62828); // red
    case AttendanceStatus.onLeave:
      return const Color(0xFF1565C0); // blue
    case AttendanceStatus.halfDay:
      return const Color(0xFF00897B); // teal
    default:
      return const Color(0xFF616161);
  }
}

Color requestStatusColor(String status) {
  switch (status) {
    case AttendanceRequestStatus.pending:
      return const Color(0xFFF9A825); // amber
    case AttendanceRequestStatus.approved:
      return const Color(0xFF2E7D32); // green
    case AttendanceRequestStatus.rejected:
      return const Color(0xFFC62828); // red
    default:
      return const Color(0xFF616161);
  }
}

/// Small rounded chip with a tinted background and colored label.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
  });

  /// Chip for an attendance record status (`PRESENT`, `LATE`, …).
  StatusChip.attendance(String status, {super.key, this.dense = false})
      : label = humanizeEnum(status),
        color = attendanceStatusColor(status);

  /// Chip for a request status (`PENDING`, `APPROVED`, `REJECTED`).
  StatusChip.request(String status, {super.key, this.dense = false})
      : label = humanizeEnum(status),
        color = requestStatusColor(status);

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: dense ? 11 : 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
