import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/attention_provider.dart';
import '../router/routes.dart';
import '../widgets/page_scaffold.dart';
import 'attendance_logs_screen.dart';
import 'live_attendance_screen.dart';
import 'missing_checkouts_screen.dart';

enum AttendanceTab { live, logs, missing }

/// Everything attendance-related under one roof.
///
/// These three views were separate top-level nav items even though they are
/// the same data at three time horizons — now, historical, and unresolved.
/// Grouping them as tabs cuts the nav in half and makes the relationship
/// obvious, while each tab keeps its own URL.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key, required this.tab});

  final AttendanceTab tab;

  static const _titles = {
    AttendanceTab.live: 'Who is in right now, refreshed automatically.',
    AttendanceTab.logs:
        'Search and correct historical attendance records.',
    AttendanceTab.missing:
        'Days someone checked in but never checked out — resolve them here.',
  };

  @override
  Widget build(BuildContext context) {
    final missingCount = context.watch<AttentionProvider>().missingCheckouts;

    return PageScaffold(
      title: 'Attendance',
      description: _titles[tab],
      currentRoute: switch (tab) {
        AttendanceTab.live => Routes.attendanceLive,
        AttendanceTab.logs => Routes.attendanceLogs,
        AttendanceTab.missing => Routes.attendanceMissing,
      },
      tabs: [
        const SectionTab(
          label: 'Live board',
          icon: Icons.sensors_outlined,
          route: Routes.attendanceLive,
        ),
        const SectionTab(
          label: 'Logs',
          icon: Icons.receipt_long_outlined,
          route: Routes.attendanceLogs,
        ),
        SectionTab(
          label: 'Missing check-outs',
          icon: Icons.timer_off_outlined,
          route: Routes.attendanceMissing,
          badge: missingCount,
        ),
      ],
      child: switch (tab) {
        AttendanceTab.live => const LiveAttendanceScreen(),
        AttendanceTab.logs => const AttendanceLogsScreen(),
        AttendanceTab.missing => const MissingCheckoutsScreen(),
      },
    );
  }
}
