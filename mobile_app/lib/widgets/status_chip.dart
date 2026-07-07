import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../models/attendance_request.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

/// Contract-defined semantic color for an attendance status.
Color attendanceStatusColor(String status) {
  switch (status) {
    case AttendanceStatus.present:
      return AppColors.success;
    case AttendanceStatus.late:
      return AppColors.warning;
    case AttendanceStatus.absent:
      return AppColors.danger;
    case AttendanceStatus.onLeave:
      return AppColors.info;
    case AttendanceStatus.halfDay:
      return AppColors.teal;
    default:
      return AppColors.slate;
  }
}

/// Semantic color for a regularization-request status.
Color requestStatusColor(String status) {
  switch (status) {
    case AttendanceRequestStatus.pending:
      return AppColors.warning;
    case AttendanceRequestStatus.approved:
      return AppColors.success;
    case AttendanceRequestStatus.rejected:
      return AppColors.danger;
    default:
      return AppColors.slate;
  }
}

/// Soft tinted pill with a saturated label/icon of the same hue.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  /// Chip for an attendance record status (`PRESENT`, `LATE`, …).
  StatusChip.attendance(String status, {super.key, this.dense = false})
      : label = humanizeEnum(status),
        color = attendanceStatusColor(status),
        icon = null;

  /// Chip for a request status (`PENDING`, `APPROVED`, `REJECTED`).
  StatusChip.request(String status, {super.key, this.dense = false})
      : label = humanizeEnum(status),
        color = requestStatusColor(status),
        icon = null;

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.tint),
        borderRadius: AppRadius.pillR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
