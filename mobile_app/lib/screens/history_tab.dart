import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../utils/formatters.dart';
import '../widgets/async_states.dart';
import '../widgets/status_chip.dart';

/// Paginated attendance history with a date-range filter.
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
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _AttendanceDetailSheet(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    Widget body;
    if (provider.historyLoading && !provider.historyLoaded) {
      body = const LoadingView(message: 'Loading history…');
    } else if (provider.historyError != null && provider.history.isEmpty) {
      body = ErrorView(
        message: provider.historyError!,
        onRetry: () => provider.loadHistory(refresh: true),
      );
    } else if (provider.history.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => provider.loadHistory(refresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyView(
                icon: Icons.event_busy_rounded,
                title: provider.historyFiltered
                    ? 'No records in the selected range'
                    : 'No attendance records yet',
                subtitle: provider.historyFiltered
                    ? 'Try a different date range.'
                    : 'Your attendance will appear here after your '
                        'first check-in.',
              ),
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => provider.loadHistory(refresh: true),
        child: ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount:
              provider.history.length + (provider.historyLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= provider.history.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
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
            return _HistoryTile(
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
          IconButton(
            tooltip: 'Filter by date range',
            onPressed: _pickRange,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
        bottom: provider.historyFiltered
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(
                        '${provider.historyFrom != null ? formatDayDate(provider.historyFrom!) : '…'}'
                        '  →  '
                        '${provider.historyTo != null ? formatDayDate(provider.historyTo!) : '…'}',
                      ),
                      onDeleted: () => provider.setHistoryRange(null, null),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: body,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.onTap});

  final Attendance record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = attendanceStatusColor(record.status);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
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
                    Text(
                      '${formatTime(record.checkIn)} → '
                      '${formatTime(record.checkOut)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Work ${formatMinutes(record.workMinutes)} · '
                      'Break ${formatMinutes(record.breakMinutes)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip.attendance(record.status, dense: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceDetailSheet extends StatelessWidget {
  const _AttendanceDetailSheet({required this.record});

  final Attendance record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now().toUtc();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (record.isLate)
                    const StatusChip(
                        label: 'Late arrival',
                        color: Color(0xFFEF6C00),
                        dense: true),
                  if (record.isEarlyOut)
                    const StatusChip(
                        label: 'Early check-out',
                        color: Color(0xFFEF6C00),
                        dense: true),
                ],
              ),
            ],
            const SizedBox(height: 16),
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
                label: 'Work duration',
                value: formatMinutes(record.workMinutes)),
            _DetailRow(
                icon: Icons.coffee_outlined,
                label: 'Break duration',
                value: formatMinutes(record.breakMinutes)),
            const SizedBox(height: 16),
            Text(
              'Breaks',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (record.breaks.isEmpty)
              Text(
                'No breaks taken.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              ...record.breaks.asMap().entries.map((entry) {
                final b = entry.value;
                final open = b.isOpen;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.coffee_rounded,
                          size: 18,
                          color: open ? scheme.primary : scheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${formatTime(b.start)} → '
                          '${open ? 'ongoing' : formatTime(b.end)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        formatMinutes(b.duration(now).inMinutes),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }),
            if (record.correction != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Corrected by admin',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if ((record.correction!.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
