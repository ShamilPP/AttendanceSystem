import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formats.dart';
import '../widgets/app_card.dart';
import '../widgets/states.dart';
import '../widgets/stat_tile.dart';

/// Stat tiles from /dashboard/stats + trends chart from /dashboard/trends.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final stats = provider.stats;
    final theme = Theme.of(context);

    if (provider.error != null && stats == null && !provider.loadingStats) {
      return ErrorState(message: provider.error!, onRetry: provider.load);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Today at a glance',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton.filledTonal(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: provider.loadingStats ? null : provider.load,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (provider.error != null && stats != null)
          ErrorBanner(message: provider.error!, onRetry: provider.load),
        if (provider.loadingStats && stats == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: LoadingState(message: 'Loading dashboard…'),
          )
        else if (stats != null)
          _StatsGrid(stats: stats),
        const SizedBox(height: AppSpacing.xl),
        _TrendsCard(provider: provider),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      StatTile(
          label: 'Total employees',
          value: '${stats.totalEmployees}',
          icon: Icons.groups_outlined,
          accentColor: AppColors.seed),
      StatTile(
          label: 'Present',
          value: '${stats.present}',
          icon: Icons.check_circle_outline,
          accentColor: AppColors.present),
      StatTile(
          label: 'Late',
          value: '${stats.late}',
          icon: Icons.schedule,
          accentColor: AppColors.late),
      StatTile(
          label: 'Absent',
          value: '${stats.absent}',
          icon: Icons.highlight_off,
          accentColor: AppColors.absent),
      StatTile(
          label: 'On leave',
          value: '${stats.onLeave}',
          icon: Icons.event_busy_outlined,
          accentColor: AppColors.onLeave),
      StatTile(
          label: 'Checked out',
          value: '${stats.checkedOut}',
          icon: Icons.logout,
          accentColor: AppColors.checkedOut),
      StatTile(
          label: 'Avg work hours',
          value: formatMinutes(stats.averageWorkMinutes),
          subtitle: 'h:mm per employee',
          icon: Icons.timelapse,
          accentColor: AppColors.halfDay),
      StatTile(
          label: 'Attendance rate',
          value: '${stats.attendanceRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          accentColor: AppColors.present),
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
