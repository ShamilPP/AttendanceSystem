import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../providers/catalog_provider.dart';
import '../providers/live_attendance_provider.dart';
import '../utils/formats.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_card.dart';
import '../widgets/states.dart';
import '../widgets/status_chip.dart';
import '../widgets/table_wrapper.dart';

/// Live board of every active employee; auto-refreshes every 30 seconds.
class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({super.key});

  @override
  State<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogProvider>().ensureLoaded();
      context.read<LiveAttendanceProvider>().fetch();
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<LiveAttendanceProvider>().fetch(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LiveAttendanceProvider>();
    final catalog = context.watch<CatalogProvider>();
    final data = provider.data;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('live-dept-${provider.departmentId}'),
                  initialValue: provider.departmentId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All departments')),
                    for (final d in catalog.departments)
                      DropdownMenuItem<String?>(
                          value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (value) => provider.setDepartment(value),
                ),
              ),
              const Spacer(),
              if (provider.lastUpdated != null)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.present, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Updated ${DateFormat('HH:mm:ss').format(provider.lastUpdated!)} · auto every 30s',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'Refresh now',
                icon: const Icon(Icons.refresh),
                onPressed: provider.loading ? null : () => provider.fetch(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (provider.error != null)
            ErrorBanner(
                message: provider.error!, onRetry: () => provider.fetch()),
          if (data != null) ...[
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                CountChip(
                    label: 'Total',
                    count: data.summary.total,
                    color: AppColors.seed,
                    icon: Icons.groups_outlined),
                CountChip(
                    label: 'Present',
                    count: data.summary.present,
                    color: AppColors.present,
                    icon: Icons.check_circle_outline),
                CountChip(
                    label: 'Late',
                    count: data.summary.late,
                    color: AppColors.late,
                    icon: Icons.schedule),
                CountChip(
                    label: 'Absent',
                    count: data.summary.absent,
                    color: AppColors.absent,
                    icon: Icons.highlight_off),
                CountChip(
                    label: 'On leave',
                    count: data.summary.onLeave,
                    color: AppColors.onLeave,
                    icon: Icons.event_busy_outlined),
                CountChip(
                    label: 'Checked out',
                    count: data.summary.checkedOut,
                    color: AppColors.checkedOut,
                    icon: Icons.logout),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Expanded(
            child: provider.loading && data == null
                ? const LoadingState(message: 'Loading live board…')
                : data == null || data.records.isEmpty
                    ? const EmptyState(
                        title: 'Nobody to show',
                        message: 'No active employees match this filter.',
                        icon: Icons.sensors_off)
                    : AppCard(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: AppRadius.cardR,
                          child: TableWrapper(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Employee')),
                                DataColumn(label: Text('Department')),
                                DataColumn(label: Text('Check-in')),
                                DataColumn(label: Text('Check-out')),
                                DataColumn(label: Text('Work (h:mm)')),
                                DataColumn(label: Text('Status')),
                              ],
                              rows: [
                                for (final r in data.records)
                                  DataRow(cells: [
                                    DataCell(EmployeeCell(
                                      name: r.employee.name,
                                      subtitle: r.employee.employeeId,
                                    )),
                                    DataCell(Text(r.employee.departmentName)),
                                    DataCell(
                                        Text(formatTime(r.attendance?.checkIn))),
                                    DataCell(Text(
                                        formatTime(r.attendance?.checkOut))),
                                    DataCell(Text(r.attendance == null
                                        ? '—'
                                        : formatMinutes(
                                            r.attendance!.workMinutes))),
                                    DataCell(StatusChip.live(r.liveStatus)),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
