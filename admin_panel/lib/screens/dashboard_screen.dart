import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dashboard.dart';
import '../providers/attention_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/live_attendance_provider.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formats.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';
import '../widgets/stat_tile.dart';

/// The admin's landing page: what needs doing, then today's numbers, then
/// the trend.
///
/// Ordered by urgency deliberately — the two queues that require a decision
/// come first, because they are the only things on this screen that go stale
/// if ignored. Every stat tile is a link into the filtered list behind it, so
/// "5 absent" is one click from *who*.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().load();
    });
    // Matches the live board's cadence — the two screens showing "today"
    // should never disagree because one of them is stale.
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<DashboardProvider>().load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Opens the live board pre-filtered to a status, so a tile answers "who?".
  void _drillDown(String? liveStatus) {
    context.read<LiveAttendanceProvider>().setStatusFilter(liveStatus);
    context.go(Routes.attendanceLive);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final stats = provider.stats;

    if (provider.error != null && stats == null && !provider.loadingStats) {
      return ErrorState(message: provider.error!, onRetry: provider.load);
    }

    return _DashboardBody(
      children: [
        const _AttentionCard(),
        if (provider.error != null && stats != null)
          ErrorBanner(message: provider.error!, onRetry: provider.load),
        if (provider.loadingStats && stats == null)
          const StatGridSkeleton()
        else if (stats != null)
          _StatsGrid(stats: stats, onDrillDown: _drillDown),
        const SizedBox(height: AppSpacing.xl),
        _TrendsCard(provider: provider),
      ],
    );
  }
}

/// The dashboard renders its own header (it needs a live "updated" line), so
/// it uses this thin body wrapper instead of the shared `PageScaffold`.
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DashboardProvider>();
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, AppSpacing.xxl),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Overview',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(today,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (provider.lastUpdated != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.present, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Updated ${DateFormat('HH:mm').format(provider.lastUpdated!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            IconButton.filledTonal(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: provider.loadingStats ? null : provider.load,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        ...children,
      ],
    );
  }
}

/// "Needs your attention" — the pending queues, surfaced instead of buried.
///
/// Collapses to a quiet all-clear strip when both queues are empty, so it
/// never becomes background noise the admin learns to skip past.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard();

  @override
  Widget build(BuildContext context) {
    final attention = context.watch<AttentionProvider>();
    final theme = Theme.of(context);

    if (!attention.hasWork) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                size: 18, color: AppColors.present),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Nothing needs your attention — no pending requests, no missing check-outs.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: AppCard(
        elevated: true,
        borderColor: AppColors.late.withValues(alpha: 0.4),
        color: AppColors.late.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    color: AppColors.late, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Needs your attention',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                if (attention.pendingRequests > 0)
                  _AttentionAction(
                    icon: Icons.pending_actions_outlined,
                    count: attention.pendingRequests,
                    label: attention.pendingRequests == 1
                        ? 'request waiting for review'
                        : 'requests waiting for review',
                    actionLabel: 'Review',
                    onPressed: () => context.go(Routes.requests),
                  ),
                if (attention.missingCheckouts > 0)
                  _AttentionAction(
                    icon: Icons.timer_off_outlined,
                    count: attention.missingCheckouts,
                    label: attention.missingCheckouts == 1
                        ? 'unresolved check-out from yesterday'
                        : 'unresolved check-outs from yesterday',
                    actionLabel: 'Resolve',
                    onPressed: () => context.go(Routes.attendanceMissing),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionAction extends StatelessWidget {
  const _AttentionAction({
    required this.icon,
    required this.count,
    required this.label,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final int count;
  final String label;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 320),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.fieldR,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.late),
          const SizedBox(width: AppSpacing.md),
          Text('$count',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.late)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: AppSpacing.lg),
          AppButton.tonal(label: actionLabel, onPressed: onPressed),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.onDrillDown});

  final DashboardStats stats;
  final ValueChanged<String?> onDrillDown;

  @override
  Widget build(BuildContext context) {
    // `onTap` is only wired where a drill-down is meaningful: aggregate
    // measures (averages, rates) have no list of people behind them.
    final cards = <Widget>[
      StatTile(
        label: 'Total employees',
        value: '${stats.totalEmployees}',
        icon: Icons.groups_outlined,
        accentColor: AppColors.seed,
        hint: 'View all',
        onTap: () => onDrillDown(null),
      ),
      StatTile(
        label: 'Present',
        value: '${stats.present}',
        icon: Icons.check_circle_outline,
        accentColor: AppColors.present,
        hint: 'Who is working',
        onTap: () => onDrillDown('WORKING'),
      ),
      StatTile(
        label: 'Late',
        value: '${stats.late}',
        icon: Icons.schedule,
        accentColor: AppColors.late,
        hint: 'See the logs',
        onTap: () => context.go(Routes.attendanceLogs),
      ),
      StatTile(
        label: 'Absent',
        value: '${stats.absent}',
        icon: Icons.highlight_off,
        accentColor: AppColors.absent,
        hint: 'Who has not come in',
        onTap: () => onDrillDown('NOT_IN'),
      ),
      StatTile(
        label: 'On leave',
        value: '${stats.onLeave}',
        icon: Icons.event_busy_outlined,
        accentColor: AppColors.onLeave,
        hint: 'Who is off',
        onTap: () => onDrillDown('ON_LEAVE'),
      ),
      StatTile(
        label: 'Checked out',
        value: '${stats.checkedOut}',
        icon: Icons.logout,
        accentColor: AppColors.checkedOut,
        hint: 'Who has left',
        onTap: () => onDrillDown('CHECKED_OUT'),
      ),
      StatTile(
        label: 'Avg work hours',
        value: formatMinutes(stats.averageWorkMinutes),
        subtitle: 'h:mm per employee',
        icon: Icons.timelapse,
        accentColor: AppColors.halfDay,
      ),
      StatTile(
        label: 'Attendance rate',
        value: '${stats.attendanceRate.toStringAsFixed(1)}%',
        icon: Icons.trending_up,
        accentColor: AppColors.present,
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / 240).floor().clamp(1, 4);
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.lg) / columns;
      return Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    });
  }
}

class _TrendsCard extends StatelessWidget {
  const _TrendsCard({required this.provider});

  final DashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Attendance trends',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 'daily', label: Text('Daily')),
                  ButtonSegment(value: 'weekly', label: Text('Weekly')),
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                ],
                selected: {provider.period},
                onSelectionChanged: (selection) =>
                    provider.setPeriod(selection.first),
              ),
              const _Legend(),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 320,
            child: provider.loadingTrends
                ? const LoadingState()
                : provider.points.isEmpty
                    ? const EmptyState(
                        title: 'No trend data yet',
                        message:
                            'Attendance trends will appear here once records start coming in.',
                        icon: Icons.bar_chart)
                    : _TrendsChart(
                        points: provider.points, period: provider.period),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        );
    return Wrap(
      spacing: AppSpacing.lg,
      children: [
        item(AppColors.present, 'Present'),
        item(AppColors.late, 'Late'),
        item(AppColors.absent, 'Absent'),
      ],
    );
  }
}

/// Grouped bar chart: present / late / absent per period point.
class _TrendsChart extends StatelessWidget {
  const _TrendsChart({required this.points, required this.period});

  final List<TrendPoint> points;
  final String period;

  static const _seriesNames = ['Present', 'Late', 'Absent'];
  static const _seriesColors = [
    AppColors.present,
    AppColors.late,
    AppColors.absent,
  ];

  String _shortLabel(String label) {
    switch (period) {
      case 'daily':
        final d = DateTime.tryParse(label);
        return d == null ? label : DateFormat('d MMM').format(d);
      case 'weekly':
        final i = label.indexOf('W');
        return i >= 0 ? label.substring(i) : label;
      case 'monthly':
        final d = DateTime.tryParse('$label-01');
        return d == null ? label : DateFormat('MMM').format(d);
      default:
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gridColor = theme.colorScheme.outlineVariant;
    final axisColor = theme.colorScheme.onSurfaceVariant;
    final tooltipBg = theme.colorScheme.inverseSurface;
    final tooltipFg = theme.colorScheme.onInverseSurface;

    var maxValue = 0;
    for (final p in points) {
      for (final v in [p.present, p.late, p.absent]) {
        if (v > maxValue) maxValue = v;
      }
    }
    final maxY = (maxValue <= 5 ? 5 : ((maxValue / 5).ceil() * 5)).toDouble();
    final yInterval = (maxY / 5).ceilToDouble();
    final labelStep = points.length > 9 ? 2 : 1;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameWidget: Text('Employees',
                style: TextStyle(color: axisColor, fontSize: 11)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: yInterval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value.toInt().toString(),
                  style: TextStyle(color: axisColor, fontSize: 11),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length || i % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _shortLabel(points[i].label),
                    style: TextStyle(color: axisColor, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => tooltipBg,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = points[group.x.toInt()];
              return BarTooltipItem(
                '${point.label}\n',
                TextStyle(
                    color: tooltipFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
                children: [
                  TextSpan(
                    text: '${_seriesNames[rodIndex]}: ${rod.toY.toInt()}',
                    style: TextStyle(
                        color: tooltipFg,
                        fontWeight: FontWeight.w400,
                        fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                for (var s = 0; s < 3; s++)
                  BarChartRodData(
                    toY: [
                      points[i].present,
                      points[i].late,
                      points[i].absent
                    ][s]
                        .toDouble(),
                    color: _seriesColors[s],
                    width: period == 'daily' ? 6 : 10,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
