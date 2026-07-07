import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Small colored chip: dot + label. Identity is never color-alone —
/// the label always names the status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  /// Attendance record status: PRESENT | LATE | ABSENT | ON_LEAVE | HALF_DAY.
  factory StatusChip.attendance(String status, {Key? key}) => StatusChip(
        key: key,
        label: _attendanceLabel(status),
        color: AppColors.forAttendanceStatus(status),
      );

  /// Live status: NOT_IN | WORKING | ON_BREAK | CHECKED_OUT | ON_LEAVE.
  factory StatusChip.live(String status, {Key? key}) => StatusChip(
        key: key,
        label: _liveLabel(status),
        color: AppColors.forLiveStatus(status),
      );

  /// Request status: PENDING | APPROVED | REJECTED.
  factory StatusChip.request(String status, {Key? key}) => StatusChip(
        key: key,
        label: _requestLabel(status),
        color: AppColors.forRequestStatus(status),
      );

  final String label;
  final Color color;

  static String _attendanceLabel(String status) {
    switch (status) {
      case 'PRESENT':
        return 'Present';
      case 'LATE':
        return 'Late';
      case 'ABSENT':
        return 'Absent';
      case 'ON_LEAVE':
        return 'On leave';
      case 'HALF_DAY':
        return 'Half day';
      default:
        return status;
    }
  }

  static String _liveLabel(String status) {
    switch (status) {
      case 'NOT_IN':
        return 'Not in';
      case 'WORKING':
        return 'Working';
      case 'ON_BREAK':
        return 'On break';
      case 'CHECKED_OUT':
        return 'Checked out';
      case 'ON_LEAVE':
        return 'On leave';
      default:
        return status;
    }
  }

  static String _requestLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pending';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Color.lerp(color, Colors.black, 0.25),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Count chip used in summary rows (live board, requests header).
class CountChip extends StatelessWidget {
  const CountChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: Color.lerp(color, Colors.black, 0.25),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Color.lerp(color, Colors.black, 0.35),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
