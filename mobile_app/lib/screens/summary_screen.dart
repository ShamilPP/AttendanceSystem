import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_summary.dart';
import '../providers/attendance_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/async_states.dart';
import '../widgets/stat_tile.dart';

/// Monthly attendance summary: month picker, a present/absent chart and a
/// grid of stat tiles (no break tile — v2 has no break tracking).
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    context.read<AttendanceProvider>().loadSummary(formatMonthParam(_month));
  }

  bool get _canGoForward {
    final now = DateTime.now();
    return _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final summary = provider.summary;

    Widget body;
    if (provider.summaryLoading) {
      body = const LoadingState(message: 'Loading summary…');
    } else if (provider.summaryError != null) {
      body = ErrorState(message: provider.summaryError!, onRetry: _load);
    } else if (summary == null) {
      body = const EmptyState(
        icon: Icons.insights_rounded,
        title: 'No summary available',
        message: 'There is no attendance data for this month yet.',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
        children: [
          _AttendanceChart(summary: summary),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.5,
            children: [
              StatTile(
                label: 'Present days',
                value: '${summary.presentDays}',
                icon: Icons.check_circle_outline_rounded,
                accentColor: AppColors.success,
              ),
              StatTile(
                label: 'Late days',
                value: '${summary.lateDays}',
                icon: Icons.schedule_rounded,
                accentColor: AppColors.warning,
              ),
              StatTile(
                label: 'Absent days',
                value: '${summary.absentDays}',
                icon: Icons.cancel_outlined,
                accentColor: AppColors.danger,
              ),
              StatTile(
                label: 'Leave days',
                value: '${summary.leaveDays}',
                icon: Icons.beach_access_rounded,
                accentColor: AppColors.info,
              ),
              StatTile(
                label: 'Total hours',
                value: formatMinutesAsHours(summary.totalWorkMinutes),
                icon: Icons.timer_outlined,
              ),
              StatTile(
                label: 'Avg hours / day',
                value: formatMinutes(summary.averageWorkMinutes),
                icon: Icons.av_timer_rounded,
              ),
              StatTile(
                label: 'Half days',
                value: '${summary.halfDays}',
                icon: Icons.hourglass_bottom_rounded,
                accentColor: AppColors.teal,
              ),
              StatTile(
                label: 'Early check-outs',
                value: '${summary.earlyOutDays}',
                icon: Icons.directions_run_rounded,
                accentColor: AppColors.warning,
              ),
            ],
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Summary')),
      body: Column(
        children: [
          _MonthPicker(
            month: _month,
            loading: provider.summaryLoading,
            canGoForward: _canGoForward,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.month,
    required this.loading,
    required this.canGoForward,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final bool loading;
  final bool canGoForward;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: loading ? null : onPrev,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                formatMonthLabel(month),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: loading || !canGoForward ? null : onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stacked bar of present (incl. late) vs absent vs leave, with a legend.
class _AttendanceChart extends StatelessWidget {
  const _AttendanceChart({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final present = summary.presentDays;
    final absent = summary.absentDays;
    final leave = summary.leaveDays;
    final total = present + absent + leave;
    final rate =
        summary.workingDays == 0 ? 0 : (present / summary.workingDays * 100);

    final segments = <(int, Color)>[
      (present, AppColors.success),
      (absent, AppColors.danger),
      (leave, AppColors.info),
    ].where((s) => s.$1 > 0).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance rate',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rate.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '$present / ${summary.workingDays} working days',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.pillR,
            child: SizedBox(
              height: 14,
              child: total == 0
                  ? ColoredBox(color: scheme.surfaceContainerHighest)
                  : Row(
                      children: [
                        for (final (value, color) in segments)
                          Expanded(
                            flex: value,
                            child: Container(
                              color: color,
                              margin: const EdgeInsets.only(right: 1.5),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _Legend(color: AppColors.success, label: 'Present', value: present),
              _Legend(color: AppColors.danger, label: 'Absent', value: absent),
              _Legend(color: AppColors.info, label: 'Leave', value: leave),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(
      {required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · $value',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
