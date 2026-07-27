import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft tinted pill: dot + label. Identity is never color-alone — the label
/// always names the status, and the hue is tuned for contrast in both themes.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  /// Attendance record status: PRESENT | LATE | ABSENT | ON_LEAVE | HALF_DAY.
  factory StatusChip.attendance(String status, {Key? key}) => StatusChip(
        key: key,
        label: _attendanceLabel(status),
        color: AppColors.forAttendanceStatus(status),
      );

  /// Live status: NOT_IN | WORKING | CHECKED_OUT | ON_LEAVE.
  factory StatusChip.live(String status, {Key? key}) => StatusChip(
        key: key,
        label: liveLabel(status),
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

  /// Human label for a live status — public so filter chips elsewhere can
  /// name the status they are filtering by using the same wording.
  static String liveLabel(String status) {
    switch (status) {
      case 'NOT_IN':
        return 'Not in';
      case 'WORKING':
        return 'Working';
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
    final brightness = Theme.of(context).brightness;
    final fg = AppColors.onTint(color, brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12),
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
              color: fg,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Count chip used in summary rows (live board, requests header, import result).
///
/// With [onTap] it doubles as a filter toggle: the summary row above a table
/// is exactly where an admin expects to click a number to see the rows it
/// counts. [selected] draws the active state.
class CountChip extends StatelessWidget {
  const CountChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    this.icon,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final int count;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final fg = AppColors.onTint(color, brightness);
    final fill = selected
        ? color.withValues(alpha: isDark ? 0.30 : 0.20)
        : color.withValues(alpha: isDark ? 0.16 : 0.10);

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: selected ? 0.75 : 0.28),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 7),
          ],
          Text(
            '$count',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}
