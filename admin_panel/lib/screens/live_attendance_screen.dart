import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../providers/catalog_provider.dart';
import '../providers/live_attendance_provider.dart';
import '../utils/formats.dart';
import '../widgets/app_feedback.dart';
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
      padding: const EdgeInsets.all(20),
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
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
              if (data != null)
                Text(
                  formatDay(data.date),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              const SizedBox(width: 16),
              if (provider.lastUpdated != null)
                Text(
                  'Updated ${DateFormat('HH:mm:ss').format(provider.lastUpdated!)} · refreshes every 30 s',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              IconButton(
                tooltip: 'Refresh now',
                icon: const Icon(Icons.refresh),
                onPressed:
                    provider.loading ? null : () => provider.fetch(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (provider.error != null)
            ErrorBanner(
                message: provider.error!, onRetry: () => provider.fetch()),
          if (data != null) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                CountChip(
                    label: 'Total',
                    count: data.summary.total,
                    color: AppColors.notIn),
                CountChip(
                    label: 'Present',
                    count: data.summary.present,
                    color: AppColors.present),
                CountChip(
                    label: 'Late',
                    count: data.summary.late,
                    color: AppColors.late),
                CountChip(
                    label: 'Absent',
                    count: data.summary.absent,
                    color: AppColors.absent),
                CountChip(
                    label: 'On leave',
                    count: data.summary.onLeave,
                    color: AppColors.onLeave),
                CountChip(
                    label: 'On break',
                    count: data.summary.onBreak,
                    color: AppColors.onBreak),
                CountChip(
                    label: 'Checked out',
                    count: data.summary.checkedOut,
                    color: AppColors.checkedOut),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Expanded(
            child: provider.loading && data == null
                ? const Center(child: CircularProgressIndicator())
                : data == null || data.records.isEmpty
                    ? const EmptyState(
                        message: 'No active employees to show.',
                        icon: Icons.sensors_off)
                    : TableWrapper(
                        child: DataTable(
                          headingTextStyle: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          columns: const [
                            DataColumn(label: Text('Employee ID')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Department')),
                            DataColumn(label: Text('Check-in')),
                            DataColumn(label: Text('Check-out')),
                            DataColumn(label: Text('Work (h:mm)')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: [
                            for (final r in data.records)
                              DataRow(cells: [
                                DataCell(Text(r.employee.employeeId)),
                                DataCell(Text(r.employee.name)),
                                DataCell(Text(r.employee.departmentName)),
                                DataCell(
                                    Text(formatTime(r.attendance?.checkIn))),
                                DataCell(
                                    Text(formatTime(r.attendance?.checkOut))),
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
        ],
      ),
    );
  }
}
