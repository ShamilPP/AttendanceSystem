import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';
import '../utils/formatters.dart';
import '../widgets/async_states.dart';
import '../widgets/stat_tile.dart';

/// Monthly attendance summary with a month picker and stat tiles.
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
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (provider.summaryLoading) {
      body = const LoadingView(message: 'Loading summary…');
    } else if (provider.summaryError != null) {
      body = ErrorView(message: provider.summaryError!, onRetry: _load);
    } else if (summary == null) {
      body = const EmptyView(
        icon: Icons.insights_rounded,
        title: 'No summary available',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.85,
            children: [
              StatTile(
                label: 'Present days',
                value: '${summary.presentDays}',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF2E7D32),
              ),
              StatTile(
                label: 'Late days',
                value: '${summary.lateDays}',
                icon: Icons.schedule_rounded,
                color: const Color(0xFFEF6C00),
              ),
              StatTile(
                label: 'Absent days',
                value: '${summary.absentDays}',
                icon: Icons.cancel_outlined,
                color: const Color(0xFFC62828),
              ),
              StatTile(
                label: 'Leave days',
                value: '${summary.leaveDays}',
                icon: Icons.beach_access_rounded,
                color: const Color(0xFF1565C0),
              ),
              StatTile(
                label: 'Half days',
                value: '${summary.halfDays}',
                icon: Icons.hourglass_bottom_rounded,
                color: const Color(0xFF00897B),
              ),
              StatTile(
                label: 'Working days',
                value: '${summary.workingDays}',
                icon: Icons.calendar_month_rounded,
              ),
              StatTile(
                label: 'Total work',
                value: formatMinutesAsHours(summary.totalWorkMinutes),
                icon: Icons.timer_outlined,
              ),
              StatTile(
                label: 'Avg work / day',
                value: formatMinutes(summary.averageWorkMinutes),
                icon: Icons.av_timer_rounded,
              ),
              StatTile(
                label: 'Break time',
                value: formatMinutesAsHours(summary.totalBreakMinutes),
                icon: Icons.coffee_outlined,
              ),
              StatTile(
                label: 'Early check-outs',
                value: '${summary.earlyOutDays}',
                icon: Icons.directions_run_rounded,
                color: const Color(0xFFEF6C00),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: provider.summaryLoading
                        ? null
                        : () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      formatMonthLabel(_month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: provider.summaryLoading || !_canGoForward
                        ? null
                        : () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
