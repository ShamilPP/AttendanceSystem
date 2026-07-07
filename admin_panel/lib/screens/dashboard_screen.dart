import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../models/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../utils/formats.dart';
import '../widgets/app_feedback.dart';
import '../widgets/stat_card.dart';

/// Stat cards from /dashboard/stats + trends chart from /dashboard/trends.
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Text('Today at a glance',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed:
                  provider.loadingStats ? null : () => provider.load(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (provider.error != null)
          ErrorBanner(
              message: provider.error!, onRetry: () => provider.load()),
        if (provider.loadingStats && stats == null)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (stats != null)
          _StatsGrid(stats: stats),
        const SizedBox(height: 20),
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
      StatCard(
          title: 'Total employees',
          value: '${stats.totalEmployees}',
          icon: Icons.people_alt_outlined,
          color: AppColors.checkedOut),
      StatCard(
          title: 'Present',
          value: '${stats.present}',
          icon: Icons.check_circle_outline,
          color: AppColors.present),
      StatCard(
          title: 'Absent',
          value: '${stats.absent}',
          icon: Icons.highlight_off,
          color: AppColors.absent),
      StatCard(
          title: 'Late',
          value: '${stats.late}',
          icon: Icons.schedule,
          color: AppColors.late),
      StatCard(
          title: 'On leave',
          value: '${stats.onLeave}',
          icon: Icons.event_busy_outlined,
          color: AppColors.onLeave),
      StatCard(
          title: 'On break',
          value: '${stats.onBreak}',
          icon: Icons.free_breakfast_outlined,
          color: AppColors.onBreak),
      StatCard(
          title: 'Checked out',
          value: '${stats.checkedOut}',
          icon: Icons.logout,
          color: AppColors.checkedOut),
      StatCard(
          title: 'Avg work hours',
          value: formatMinutes(stats.averageWorkMinutes),
          subtitle: 'h:mm per employee',
          icon: Icons.timelapse,
          color: AppColors.halfDay),
      StatCard(
          title: 'Attendance rate',
          value: '${stats.attendanceRate.toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: AppColors.present),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / 250).floor().clamp(1, 5);
      final width =
          (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Attendance trends',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                      visualDensity: VisualDensity.compact),
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
            const SizedBox(height: 20),
            SizedBox(
              height: 320,
              child: provider.loadingTrends
                  ? const Center(child: CircularProgressIndicator())
                  : provider.points.isEmpty
                      ? const EmptyState(
                          message: 'No trend data yet.',
                          icon: Icons.bar_chart)
                      : _TrendsChart(
                          points: provider.points,
                          period: provider.period),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.axisLabel)),
          ],
        );
    return Wrap(
      spacing: 14,
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
        // YYYY-MM-DD -> dd MMM
        final d = DateTime.tryParse(label);
        return d == null
            ? label
            : DateFormat('d MMM').format(d);
      case 'weekly':
        // 2026-W27 -> W27
        final i = label.indexOf('W');
        return i >= 0 ? label.substring(i) : label;
      case 'monthly':
        // 2026-07 -> Jul
        final d = DateTime.tryParse('$label-01');
        return d == null ? label : DateFormat('MMM').format(d);
      default:
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    var maxValue = 0;
    for (final p in points) {
      for (final v in [p.present, p.late, p.absent]) {
        if (v > maxValue) maxValue = v;
      }
    }
    final maxY = (maxValue <= 5 ? 5 : ((maxValue / 5).ceil() * 5)).toDouble();
    // maxY is always >= 5, so this interval is always >= 1.
    final yInterval = (maxY / 5).ceilToDouble();
    // Skip alternate bottom labels when the axis gets crowded.
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
              const FlLine(color: AppColors.gridLine, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Employees',
                style: TextStyle(color: AppColors.axisLabel, fontSize: 11)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: yInterval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                      color: AppColors.axisLabel, fontSize: 11),
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
                    style: const TextStyle(
                        color: AppColors.axisLabel, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.tooltipBg,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = points[group.x.toInt()];
              return BarTooltipItem(
                '${point.label}\n',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
                children: [
                  TextSpan(
                    text:
                        '${_seriesNames[rodIndex]}: ${rod.toY.toInt()}',
                    style: const TextStyle(
                        color: Colors.white,
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
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
