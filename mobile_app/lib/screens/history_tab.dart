import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import '../widgets/async_states.dart';
import '../widgets/status_chip.dart';

/// Paginated attendance history with a date-range filter and day cards.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AttendanceProvider>();
      if (!provider.historyLoaded) provider.loadHistory();
    });
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      context.read<AttendanceProvider>().loadMoreHistory();
    }
  }

  Future<void> _pickRange() async {
    final provider = context.read<AttendanceProvider>();
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange:
          provider.historyFrom != null && provider.historyTo != null
              ? DateTimeRange(
                  start: provider.historyFrom!, end: provider.historyTo!)
              : null,
      helpText: 'Filter attendance history',
    );
    if (picked == null) return;
    await provider.setHistoryRange(picked.start, picked.end);
  }

  void _showDetail(Attendance record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AttendanceDetailSheet(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    Widget body;
    if (provider.historyLoading && !provider.historyLoaded) {
      body = const LoadingState(message: 'Loading history…');
    } else if (provider.historyError != null && provider.history.isEmpty) {
      body = ErrorState(
        message: provider.historyError!,
        onRetry: () => provider.loadHistory(refresh: true),
      );
    } else if (provider.history.isEmpty) {
      body = _RefreshableEmpty(
        onRefresh: () => provider.loadHistory(refresh: true),
        child: EmptyState(
          icon: Icons.event_busy_rounded,
          title: provider.historyFiltered
              ? 'No records in this range'
              : 'No attendance records yet',
          message: provider.historyFiltered
              ? 'Try a different date range.'
              : 'Your attendance will appear here after your first check-in.',
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => provider.loadHistory(refresh: true),
        child: ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
          itemCount:
              provider.history.length + (provider.historyLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            if (index >= provider.history.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              );
            }
            final record = provider.history[index];
            return _HistoryCard(
                record: record, onTap: () => _showDetail(record));
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (provider.historyFiltered)
            IconButton(
              tooltip: 'Clear filter',
              onPressed: () => provider.setHistoryRange(null, null),
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            filtered: provider.historyFiltered,
            from: provider.historyFrom,
            to: provider.historyTo,
            onPick: _pickRange,
            onClear: () => provider.setHistoryRange(null, null),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filtered,
    required this.from,
    required this.to,
    required this.onPick,
    required this.onClear,
  });

  final bool filtered;
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          if (filtered)
            Expanded(
              child: InputChip(
                avatar: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  '${from != null ? formatDayDate(from!) : '…'}'
                  '  →  '
                  '${to != null ? formatDayDate(to!) : '…'}',
                  overflow: TextOverflow.ellipsis,
                ),
                onDeleted: onClear,
              ),
            )
          else
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: const Text('Filter by date range'),
                  onPressed: onPick,
                ),
              ),
            ),
          if (filtered) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              tooltip: 'Change range',
              onPressed: onPick,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _RefreshableEmpty extends StatelessWidget {
  const _RefreshableEmpty({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: constraints.maxHeight, child: child),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record, required this.onTap});

  final Attendance record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = attendanceStatusColor(record.status);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: AppColors.tint),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(record.status), color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateString(record.date),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.login_rounded,
                            size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(formatTime(record.checkIn),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: AppSpacing.md),
                        Icon(Icons.logout_rounded,
                            size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(formatTime(record.checkOut),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Worked ${formatMinutes(record.workMinutes)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip.attendance(record.status, dense: true),
                  const SizedBox(height: AppSpacing.sm),
                  Icon(Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle_outline_rounded;
      case AttendanceStatus.late:
        return Icons.schedule_rounded;
      case AttendanceStatus.absent:
        return Icons.cancel_outlined;
      case AttendanceStatus.onLeave:
        return Icons.beach_access_rounded;
      case AttendanceStatus.halfDay:
        return Icons.hourglass_bottom_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }
}

class _AttendanceDetailSheet extends StatelessWidget {
  const _AttendanceDetailSheet({required this.record});

  final Attendance record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatDateString(record.date),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip.attendance(record.status),
              ],
            ),
            if (record.isLate || record.isEarlyOut) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (record.isLate)
                    const StatusChip(
                        label: 'Late arrival',
                        color: AppColors.warning,
                        icon: Icons.schedule_rounded,
                        dense: true),
                  if (record.isEarlyOut)
                    const StatusChip(
                        label: 'Early check-out',
                        color: AppColors.warning,
                        icon: Icons.directions_run_rounded,
                        dense: true),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _DetailRow(
                icon: Icons.login_rounded,
                label: 'Check-in',
                value: formatTime(record.checkIn, placeholder: '—')),
            _DetailRow(
                icon: Icons.logout_rounded,
                label: 'Check-out',
                value: formatTime(record.checkOut, placeholder: '—')),
            _DetailRow(
                icon: Icons.timer_outlined,
                label: 'Worked',
                value: formatMinutes(record.workMinutes)),
            if (record.checkInLocation != null)
              _DetailRow(
                icon: Icons.place_outlined,
                label: 'Location',
                value: 'Verified at the office',
              ),
            if (record.correction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: AppRadius.fieldR,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note_rounded,
                            size: 18, color: scheme.onTertiaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          'Corrected by admin',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if ((record.correction!.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(record.correction!.note!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
