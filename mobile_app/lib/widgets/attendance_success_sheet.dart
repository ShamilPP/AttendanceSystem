import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import 'app_button.dart';
import 'status_chip.dart';

/// Confirmation sheet shown after a successful scan.
///
/// Lives here rather than on Home because the scan can now be launched from
/// the shell's FAB on any tab — both entry points must confirm identically.
Future<void> showAttendanceSuccessSheet(
  BuildContext context,
  AttendanceAction action,
  ScanOutcome outcome,
) {
  final attendance = outcome.attendance;
  final DateTime when = (action == AttendanceAction.checkIn
          ? attendance?.checkIn
          : attendance?.checkOut) ??
      DateTime.now();
  final accent =
      action == AttendanceAction.checkIn ? AppColors.success : AppColors.danger;

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: AppColors.tint),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 46, color: accent),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${action.label} successful',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatDateTime(when),
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              if (attendance != null)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    StatusChip.attendance(attendance.status),
                    if (attendance.isLate && action == AttendanceAction.checkIn)
                      const StatusChip(
                          label: 'Marked late',
                          color: AppColors.warning,
                          icon: Icons.warning_amber_rounded),
                    if (attendance.isEarlyOut &&
                        action == AttendanceAction.checkOut)
                      const StatusChip(
                          label: 'Early check-out',
                          color: AppColors.warning,
                          icon: Icons.warning_amber_rounded),
                    if (action == AttendanceAction.checkOut)
                      StatusChip(
                          label:
                              'Worked ${formatMinutes(attendance.workMinutes)}',
                          color: AppColors.info,
                          icon: Icons.timer_outlined),
                  ],
                ),
              if (outcome.message.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  outcome.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Done',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
