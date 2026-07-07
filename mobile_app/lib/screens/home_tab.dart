import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/formatters.dart';
import '../widgets/status_chip.dart';
import 'scan_screen.dart';
import 'summary_screen.dart';

/// Greeting, live today card, and the four scan actions.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AttendanceProvider>().loadToday();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _startAction(AttendanceAction action) async {
    final outcome = await Navigator.of(context).push<ScanOutcome>(
      MaterialPageRoute(builder: (_) => ScanScreen(action: action)),
    );
    if (outcome == null || !mounted) return;
    await _showSuccessSheet(action, outcome);
  }

  Future<void> _showSuccessSheet(
      AttendanceAction action, ScanOutcome outcome) async {
    final attendance = outcome.attendance;
    DateTime? when;
    switch (action) {
      case AttendanceAction.checkIn:
        when = attendance?.checkIn;
      case AttendanceAction.checkOut:
        when = attendance?.checkOut;
      case AttendanceAction.breakStart:
        when = attendance?.openBreak?.start ??
            (attendance != null && attendance.breaks.isNotEmpty
                ? attendance.breaks.last.start
                : null);
      case AttendanceAction.breakEnd:
        when = attendance != null && attendance.breaks.isNotEmpty
            ? attendance.breaks.last.end
            : null;
    }
    when ??= DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 40, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(height: 14),
                Text(
                  '${action.label} successful',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDateTime(when),
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                if (attendance != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      StatusChip.attendance(attendance.status),
                      if (attendance.isLate &&
                          action == AttendanceAction.checkIn)
                        const StatusChip(
                            label: 'Marked late',
                            color: Color(0xFFEF6C00)),
                      if (attendance.isEarlyOut &&
                          action == AttendanceAction.checkOut)
                        const StatusChip(
                            label: 'Early check-out',
                            color: Color(0xFFEF6C00)),
                    ],
                  ),
                if (outcome.message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    outcome.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: 'Monthly summary',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const SummaryScreen()),
              );
            },
            icon: const Icon(Icons.insights_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AttendanceProvider>().loadToday(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              '${greetingFor(now)}, ${auth.user?.firstName ?? 'there'}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              formatFullDate(now),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            _TodayCard(provider: attendance, now: now),
            const SizedBox(height: 20),
            Text(
              'Actions',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _ActionGrid(provider: attendance, onAction: _startAction),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.insights_rounded),
                title: const Text('Monthly summary'),
                subtitle:
                    const Text('Working days, hours and attendance stats'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SummaryScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.provider, required this.now});

  final AttendanceProvider provider;
  final DateTime now;

  String _stateLabel(Attendance? a) {
    if (a == null || a.checkIn == null) {
      if (a?.status == AttendanceStatus.onLeave) return 'On leave today';
      return 'Not checked in yet';
    }
    if (a.checkOut != null) return 'Checked out';
    if (a.hasOpenBreak) return 'On break';
    return 'Working';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = provider.today;

    Widget content;
    if (provider.todayLoading && !provider.todayLoaded) {
      content = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (provider.todayError != null && !provider.todayLoaded) {
      content = Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              provider.todayError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: provider.loadToday,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    } else {
      final utcNow = now.toUtc();
      final worked = a?.liveWorkDuration(utcNow) ?? Duration.zero;
      final onBreak = a?.liveBreakDuration(utcNow) ?? Duration.zero;
      content = Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _stateLabel(a),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (a != null) StatusChip.attendance(a.status),
              ],
            ),
            if (a != null && (a.isLate || a.isEarlyOut)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (a.isLate)
                    const StatusChip(
                        label: 'Late arrival',
                        color: Color(0xFFEF6C00),
                        dense: true),
                  if (a.isEarlyOut)
                    const StatusChip(
                        label: 'Early check-out',
                        color: Color(0xFFEF6C00),
                        dense: true),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _TimeCell(
                  label: 'Check-in',
                  value: formatTime(a?.checkIn),
                  icon: Icons.login_rounded,
                ),
                _TimeCell(
                  label: 'Check-out',
                  value: formatTime(a?.checkOut),
                  icon: Icons.logout_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _TimeCell(
                  label: 'Worked',
                  value: a?.checkIn == null
                      ? '—'
                      : (a!.checkOut != null
                          ? formatMinutes(a.workMinutes)
                          : formatLiveDuration(worked)),
                  icon: Icons.timer_outlined,
                  highlight: a?.checkIn != null && a?.checkOut == null,
                ),
                _TimeCell(
                  label: 'Break',
                  value: a == null || a.checkIn == null
                      ? '—'
                      : (a.checkOut != null
                          ? formatMinutes(a.breakMinutes)
                          : formatLiveDuration(onBreak)),
                  icon: Icons.coffee_outlined,
                  highlight: a?.hasOpenBreak ?? false,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: content,
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: highlight ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: highlight ? scheme.primary : null,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.provider, required this.onAction});

  final AttendanceProvider provider;
  final Future<void> Function(AttendanceAction) onAction;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        AttendanceAction.checkIn,
        Icons.login_rounded,
        provider.canCheckIn,
      ),
      (
        AttendanceAction.checkOut,
        Icons.logout_rounded,
        provider.canCheckOut,
      ),
      (
        AttendanceAction.breakStart,
        Icons.coffee_rounded,
        provider.canStartBreak,
      ),
      (
        AttendanceAction.breakEnd,
        Icons.play_arrow_rounded,
        provider.canEndBreak,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.3,
      children: [
        for (final (action, icon, enabled) in actions)
          _ActionButton(
            action: action,
            icon: icon,
            enabled: enabled,
            onTap: () => onAction(action),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final AttendanceAction action;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = action == AttendanceAction.checkIn ||
        action == AttendanceAction.checkOut;
    final button = primary
        ? FilledButton.icon(
            onPressed: enabled ? onTap : null,
            icon: Icon(icon),
            label: Text(action.label),
          )
        : FilledButton.tonalIcon(
            onPressed: enabled ? onTap : null,
            icon: Icon(icon),
            label: Text(action.label),
          );
    return button;
  }
}
